// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Membership NFT Smart Contracts
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IMembershipBackingToken.sol";
import "./IEcosystemFactorySponsor.sol";

/// @notice Chainlink Aggregator V3 interface for non-USDC product pricing.
/// @notice Minimal hook to update backing token treasury; implemented by `BackingToken` / `USDCReserveToken`.
interface IBackingTokenTreasury {
    function setTreasury(address newTreasury) external;
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (
        uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
    );
}

/// @title MembershipNFT
/// @notice Soulbound ERC-721 membership (Bronze–Diamond) per product; sequential purchases mint IG via `IMembershipBackingToken`.
/// @dev Transfers between wallets revert (`SoulboundToken`). USDC product uses fixed decimals; other products use `priceFeed`. Owner is `ecosystemFactory` at deploy.
contract MembershipNFT is ERC721, ERC721Enumerable, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice Backing token (IG) this membership sells and mints through.
    IMembershipBackingToken public immutable tokenContract;
    /// @notice Default sponsor allowed on first-tier purchase without holding an NFT.
    address public immutable rootAffiliate;
    /// @notice Factory for cross-product sponsor checks; zero disables `sponsorHasAnyMembership` path.
    address public immutable ecosystemFactory;
    /// @notice Oracle for non-USDC products; zero when only USDC pricing is used.
    AggregatorV3Interface public immutable priceFeed;
    /// @notice Max age (seconds) for a Chainlink answer before revert.
    uint256 public immutable maxStaleness;

    /// @notice Fixed tier economics: USDC-equivalent price (6 decimals), IG participation cap, affiliate share (bps).
    struct Tier {
        uint256 priceUSDC6;
        uint256 tokenCap;
        uint256 affiliateRateBps;
    }

    /// @notice Tier catalog index: 0 Bronze … 4 Diamond.
    Tier[5] public tiers;

    /// @notice Next tier index a wallet may purchase per product (`0` = Bronze eligible if never bought).
    mapping(uint8 => mapping(address => uint8)) public nextTierToBuy;

    /// @notice Sponsor locked on first mint per wallet+product; reused for upgrade affiliate routing.
    mapping(uint8 => mapping(address => address)) public sponsorOfFirstMint;

    /// @notice On-chain metadata for a minted token.
    struct Membership {
        uint8 productId;
        uint8 tierLevel;
        uint256 tokenCap;
        uint256 purchasePriceUSDC;
        uint256 purchaseTimestamp;
    }

    /// @notice Membership record by token id.
    mapping(uint256 => Membership) public membershipData;

    /// @notice Optional hot-path cache for `ProtocolRouter` / `FeeParticipationAccumulator`: highest tier and max
    ///         participation cap for this wallet on `productId` after the last mint on this collection. Invalid
    ///         until set by `mintMembership` or `mintMarketingBronze`; full scan is used as fallback when unset.
    struct TierScanCache {
        bool valid;
        uint8 highestTier;
        uint256 maxParticipationCap;
    }

    mapping(uint8 productId => mapping(address account => TierScanCache)) private _tierScanCache;

    uint256 private _tokenIdCounter;

    /// @notice Count of owner-issued marketing Bronze mints per product.
    mapping(uint8 => uint8) public marketingMintsCount;
    /// @notice Cap on `mintMarketingBronze` per `productId` (testnet: single in-house anchor Bronze per lane).
    uint8 public constant MAX_MARKETING_MINTS = 1;

    /// @notice HTTPS URL for ERC-721 metadata `image` (public `nft.svg` on ignitus.network).
    string private constant TOKEN_URI_IMAGE = "https://ignitus.network/nft/nft.svg";

    /// @notice Thrown on any transfer where both `from` and `to` are non-zero (soulbound).
    error SoulboundToken();
    /// @notice Oracle round or timestamp failed freshness checks.
    error StaleOraclePrice();
    /// @notice Non-positive or otherwise unusable oracle answer.
    error InvalidOracleAnswer();
    /// @notice Non-USDC pricing requested but `priceFeed` is unset.
    error OracleRequired();

    /// @notice Emitted when a membership token is minted (paid or marketing).
    event MembershipMinted(address indexed to, uint256 tokenId, uint8 productId, uint8 tierLevel, address indexed sponsor);

    /// @param _tokenContract IG / backing token (must implement `IMembershipBackingToken`).
    /// @param _rootAffiliate Root sponsor address for first-tier rules.
    /// @param _ecosystemFactory Ownable admin and optional global sponsor registry.
    /// @param _priceFeed Chainlink feed, or `address(0)` if unused.
    /// @param _maxStaleness Max oracle staleness in seconds.
    /// @param name_ ERC-721 name.
    /// @param symbol_ ERC-721 symbol.
    constructor(
        address _tokenContract,
        address _rootAffiliate,
        address _ecosystemFactory,
        address _priceFeed,
        uint256 _maxStaleness,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(_ecosystemFactory) {
        require(_rootAffiliate != address(0), "Zero address");
        tokenContract = IMembershipBackingToken(_tokenContract);
        rootAffiliate = _rootAffiliate;
        ecosystemFactory = _ecosystemFactory;
        priceFeed = AggregatorV3Interface(_priceFeed);
        maxStaleness = _maxStaleness;
        tiers[0] = Tier(243e6,   1_000 * 1e18, 1_000);   // Bronze: 10%
        tiers[1] = Tier(972e6,   5_000 * 1e18, 1_250);   // Silver: 12.5%
        tiers[2] = Tier(2430e6,  15_000 * 1e18, 1_500);  // Gold: 15%
        tiers[3] = Tier(7290e6,  60_000 * 1e18, 1_750);  // Platinum: 17.5%
        tiers[4] = Tier(21880e6, 225_000 * 1e18, 2_000); // Diamond: 20%
    }

    /// @dev Normalizes Chainlink `answer` to 8 decimals for backing-asset price math.
    function _getOracleSpotUsd8() internal view returns (uint256) {
        if (address(priceFeed) == address(0)) revert OracleRequired();
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        if (answer <= 0) revert InvalidOracleAnswer();
        if (answeredInRound < roundId) revert StaleOraclePrice();
        if (block.timestamp - updatedAt > maxStaleness) revert StaleOraclePrice();
        uint8 feedDecimals = priceFeed.decimals();
        if (feedDecimals == 8) return uint256(answer);
        if (feedDecimals < 8) return uint256(answer) * 10 ** (8 - feedDecimals);
        return uint256(answer) / 10 ** (feedDecimals - 8);
    }

    /// @notice Pay backing, mint membership NFT, credit backing on token, and mint IG splits to treasury and sponsor.
    /// @param productId Product lane `0`–`2` (USDC, Gold, WBTC); must match `mintMarketingBronze`.
    /// @param desiredTier Tier to buy; must equal `nextTierToBuy[productId][msg.sender]`.
    /// @param sponsor Affiliate recipient; must pass `isValidSponsor` (except first-tier + root path).
    function mintMembership(uint8 productId, uint8 desiredTier, address sponsor) external {
        require(productId < 3, "Invalid product ID");
        require(desiredTier < 5, "Invalid tier");
        uint8 nextAllowed = nextTierToBuy[productId][msg.sender];
        require(desiredTier == nextAllowed, "Must buy next sequential tier");

        if (desiredTier > 0) {
            uint256 currentTierCap = tiers[desiredTier - 1].tokenCap;
            require(
                IERC20(address(tokenContract)).balanceOf(msg.sender) >= currentTierCap / 2,
                "Upgrade locked: Must hold 50% of current tier tokens"
            );
        }

        require(sponsor != address(0), "Sponsor required");
        require(sponsor != msg.sender, "Self sponsor");
        if (desiredTier == 0) {
            require(sponsor == rootAffiliate || isValidSponsor(productId, sponsor), "Invalid sponsor");
        } else {
            require(isValidSponsor(productId, sponsor), "Invalid sponsor");
        }

        address lockedSponsor = sponsorOfFirstMint[productId][msg.sender];
        if (lockedSponsor != address(0)) {
            require(sponsor == lockedSponsor, "Sponsor mismatch");
        }

        // Cache the tier struct once to replace three separate SLOADs on priceUSDC6 / affiliateRateBps
        // / tokenCap with MLOADs (one initial copy).
        Tier memory tier = tiers[desiredTier];
        uint256 price6 = tier.priceUSDC6;
        uint256 decimals = tokenContract.backingDecimals();
        uint256 priceInBacking;
        if (productId == 0) {
            priceInBacking = decimals >= 6
                ? price6 * (10 ** (decimals - 6))
                : price6 / (10 ** (6 - decimals));
        } else {
            uint256 spotUsd8 = _getOracleSpotUsd8();
            priceInBacking = (price6 * (10 ** (decimals + 2))) / spotUsd8;
        }
        require(priceInBacking > 0, "Price too small");

        tokenContract.backingAsset().safeTransferFrom(msg.sender, address(tokenContract), priceInBacking);

        uint256 companyAmountBacking = (priceInBacking * 50) / 100;
        uint256 affiliateAmountBacking = (priceInBacking * tier.affiliateRateBps) / 10_000;

        uint256 V = tokenContract.totalBacking();
        uint256 S = IERC20(address(tokenContract)).totalSupply();

        uint256 companyAmount18;
        uint256 affiliateAmount18;
        if (S == 0 || V == 0) {
            uint256 startingPrice = tokenContract.startingPriceUsd6();
            companyAmount18 = (companyAmountBacking * 1e18) / startingPrice;
            affiliateAmount18 = (affiliateAmountBacking * 1e18) / startingPrice;
        } else {
            companyAmount18 = (companyAmountBacking * S) / V;
            affiliateAmount18 = (affiliateAmountBacking * S) / V;
        }

        // --- Effects (CEI: state before external calls / callbacks) ---
        uint256 tokenId = _tokenIdCounter++;

        membershipData[tokenId] = Membership({
            productId: productId,
            tierLevel: desiredTier,
            tokenCap: tier.tokenCap,
            purchasePriceUSDC: price6,
            purchaseTimestamp: block.timestamp
        });

        nextTierToBuy[productId][msg.sender] = desiredTier + 1;

        _tierScanCache[productId][msg.sender] =
            TierScanCache({valid: true, highestTier: desiredTier, maxParticipationCap: tier.tokenCap});

        if (sponsorOfFirstMint[productId][msg.sender] == address(0)) {
            sponsorOfFirstMint[productId][msg.sender] = sponsor;
        }

        // --- Interactions ---
        tokenContract.addBackingFromMembership(priceInBacking);
        tokenContract.mintForMembership(
            tokenContract.treasury(),
            sponsor,
            companyAmount18,
            affiliateAmount18
        );

        _safeMint(msg.sender, tokenId);

        emit MembershipMinted(msg.sender, tokenId, productId, desiredTier, sponsor);
    }

    /// @notice Owner-only Bronze mint without payment or IG mint; capped per product (`MAX_MARKETING_MINTS`).
    /// @dev Typical testnet flow: one marketing Bronze per product to the anchor wallet with
    ///      `affiliateRecipient == address(0)` (sponsor locks on first paid upgrade). Further Bronze memberships
    ///      use paid `mintMembership` with a valid sponsor (e.g. the anchor). One soulbound NFT per recipient.
    /// @param productId Product lane `0..2`.
    /// @param recipient Wallet receiving the soulbound NFT.
    /// @param affiliateRecipient Locked sponsor for upgrades when non-zero; `address(0)` = anchor (no lock until first paid mint).
    function mintMarketingBronze(uint8 productId, address recipient, address affiliateRecipient) external onlyOwner {
        require(productId < 3, "Invalid product ID");
        require(marketingMintsCount[productId] < MAX_MARKETING_MINTS, "Marketing allocation exhausted");
        require(recipient != address(0), "Zero address");
        require(balanceOf(recipient) == 0, "Already holds membership");

        if (affiliateRecipient != address(0)) {
            require(recipient != affiliateRecipient, "Self sponsor");
            require(isValidSponsor(productId, affiliateRecipient), "Invalid sponsor");
            sponsorOfFirstMint[productId][recipient] = affiliateRecipient;
        }

        uint256 tokenId = _tokenIdCounter++;
        _safeMint(recipient, tokenId);

        membershipData[tokenId] = Membership({
            productId: productId,
            tierLevel: 0, // Bronze
            tokenCap: tiers[0].tokenCap,
            purchasePriceUSDC: 0,
            purchaseTimestamp: block.timestamp
        });

        if (nextTierToBuy[productId][recipient] < 1) {
            nextTierToBuy[productId][recipient] = 1;
        }

        _tierScanCache[productId][recipient] = TierScanCache({
            valid: true,
            highestTier: 0,
            maxParticipationCap: tiers[0].tokenCap
        });

        marketingMintsCount[productId]++;

        emit MembershipMinted(recipient, tokenId, productId, 0, affiliateRecipient);
    }

    /// @notice Whether `sponsor` may sponsor a purchase: root, global factory membership, or any NFT on this collection.
    function isValidSponsor(uint8 /* productId */, address sponsor) public view returns (bool) {
        if (sponsor == rootAffiliate) return true;
        if (ecosystemFactory != address(0)) {
            try IEcosystemFactorySponsor(ecosystemFactory).sponsorHasAnyMembership(sponsor) returns (bool globalOk) {
                if (globalOk) return true;
            } catch {}
        }
        return balanceOf(sponsor) > 0;
    }

    /// @notice IG participation cap encoded at mint for `tokenId`.
    function getParticipationCap(uint256 tokenId) external view returns (uint256) {
        return membershipData[tokenId].tokenCap;
    }

    /// @notice Full `Membership` struct for `tokenId`.
    function getMembership(uint256 tokenId) external view returns (Membership memory) {
        return membershipData[tokenId];
    }

    /// @notice Cached highest tier and cap for `account` on `productId` (marginal gas for fee/cap readers).
    function getTierScanCache(uint8 productId, address account)
        external
        view
        returns (bool valid, uint8 highestTier, uint256 maxParticipationCap)
    {
        TierScanCache memory c = _tierScanCache[productId][account];
        return (c.valid, c.highestTier, c.maxParticipationCap);
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721: invalid token ID");

        Membership memory m = membershipData[tokenId];
        string memory product = _productName(m.productId);
        string memory tier = _tierName(m.tierLevel);

        string memory nameJson = string.concat(
            "Ignitus ",
            _productLabelForMembershipName(m.productId),
            " Membership #",
            Strings.toString(tokenId)
        );

        string memory attributes = string.concat(
            '[{"trait_type":"Product","value":"', product,
            '"},{"trait_type":"Tier","value":"', tier,
            '"},{"trait_type":"Product ID","value":"', Strings.toString(m.productId),
            '"},{"trait_type":"Tier Level","value":"', Strings.toString(m.tierLevel),
            '"},{"trait_type":"Token Cap","display_type":"number","value":"', Strings.toString(m.tokenCap),
            '"},{"trait_type":"Soulbound","value":"true"}]'
        );

        string memory json = string.concat(
            '{"name":"', nameJson,
            '","description":"IGNITUS soulbound membership NFT. Non-transferable; tier and product encoded on-chain.",',
            '"image":"', TOKEN_URI_IMAGE,
            '","attributes":', attributes,
            "}"
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    /// @dev JSON display name for `productId` in `tokenURI` attributes.
    function _productName(uint8 productId) internal pure returns (string memory) {
        if (productId == 0) return "USD";
        if (productId == 1) return "GOLD";
        if (productId == 2) return "BTC";
        return "UNKNOWN";
    }

    /// @dev Product fragment for metadata + ERC721 `name_`: "Ignitus {label} Membership" (no tier; tier is only in attributes).
    function _productLabelForMembershipName(uint8 productId) internal pure returns (string memory) {
        if (productId == 0) return "USD";
        if (productId == 1) return "Gold";
        if (productId == 2) return "BTC";
        return "Unknown";
    }

    /// @dev JSON display name for `tierLevel` in `tokenURI`.
    function _tierName(uint8 tierLevel) internal pure returns (string memory) {
        if (tierLevel == 0) return "Bronze";
        if (tierLevel == 1) return "Silver";
        if (tierLevel == 2) return "Gold";
        if (tierLevel == 3) return "Platinum";
        if (tierLevel == 4) return "Diamond";
        return "Unknown";
    }

    /// @notice Accepts pending `Ownable2Step` ownership of `tokenContract` (one-time setup).
    function acceptTokenOwnership() external {
        IOwnable2Step(address(tokenContract)).acceptOwnership();
    }

    /// @notice Updates the IG token treasury (company fee + membership mint recipient). Callable only by this NFT’s owner (`ecosystemFactory`).
    /// @dev After deploy, `tokenContract` owner is this contract; use `EcosystemFactory.setProductTokenTreasury` from the factory owner (e.g. multisig).
    function setTokenTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Zero address");
        IBackingTokenTreasury(address(tokenContract)).setTreasury(newTreasury);
    }

    /// @inheritdoc ERC721
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC721
    function _increaseBalance(address account, uint128 amount) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }

    /// @dev Allows mint/burn; reverts on wallet-to-wallet transfer (`SoulboundToken`).
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert SoulboundToken();
        }
        return super._update(to, tokenId, auth);
    }
}

interface IOwnable2Step {
    function acceptOwnership() external;
}

