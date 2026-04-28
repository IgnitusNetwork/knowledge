// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Protocol Router Smart Contracts
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BackingToken.sol";
import "./MembershipNFT.sol";
import "./EcosystemFactory.sol";

/// @title ProtocolRouter
/// @notice User-facing entrypoint for discounted `BackingToken` buy/refund fees based on highest `MembershipNFT` tier per product.
/// @dev Reads product addresses from `EcosystemFactory`; fee basis points are integer approximations of fractional percentages.
contract ProtocolRouter is ReentrancyGuard {
    /// @notice Registry of deployed product token / NFT / accumulator addresses.
    EcosystemFactory public immutable factory;

    /// @dev Swap fee tiers: non-member 1%; Bronze–Diamond stepped down (~0.9%–0.8%). Silver/Platinum values round half-bps to whole bps.
    uint256 internal constant BPS_NON_MEMBER = 100;
    uint256 internal constant BPS_BRONZE = 90;
    uint256 internal constant BPS_SILVER = 88;
    uint256 internal constant BPS_GOLD = 85;
    uint256 internal constant BPS_PLATINUM = 83;
    uint256 internal constant BPS_DIAMOND = 80;

    /// @param _factory Ignitus `EcosystemFactory` instance.
    constructor(address _factory) {
        factory = EcosystemFactory(_factory);
    }

    /// @dev Fee bps for a known highest tier (Bronze–Diamond).
    function _feeBpsForHighestTier(uint8 highestTier) internal pure returns (uint256) {
        if (highestTier == 0) return BPS_BRONZE;
        if (highestTier == 1) return BPS_SILVER;
        if (highestTier == 2) return BPS_GOLD;
        if (highestTier == 3) return BPS_PLATINUM;
        return BPS_DIAMOND;
    }

    /// @dev Highest tier for `user` on `productId`: `MembershipNFT.getTierScanCache` when set, else scan (≤5 NFTs).
    function _highestMembershipTier(uint8 productId, address user, MembershipNFT nft)
        internal
        view
        returns (uint8 highestTier, bool foundAny)
    {
        (bool cacheValid, uint8 cachedHighest,) = nft.getTierScanCache(productId, user);
        if (cacheValid) {
            return (cachedHighest, true);
        }

        // Note: `balance` is naturally capped at 5 because memberships are sequential Bronze→Diamond
        // on a per-product NFT contract, and each tier mints one soulbound NFT.
        // `unchecked { ++i; }` is safe because `i` is bounded by that 5-NFT invariant.
        uint256 balance = nft.balanceOf(user);
        for (uint256 i = 0; i < balance; ) {
            uint256 tokenId = nft.tokenOfOwnerByIndex(user, i);
            MembershipNFT.Membership memory data = nft.getMembership(tokenId);
            if (data.productId == productId) {
                foundAny = true;
                if (data.tierLevel > highestTier) highestTier = data.tierLevel;
                if (highestTier == 4) break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Resolves fee bps for `user` on `productId` from their highest-tier NFT on that product (or non-member default).
    /// @dev Uses `MembershipNFT.getTierScanCache` when set (after mint); otherwise scans `balanceOf(user)` NFTs.
    /// @param productId Factory product lane (`0`–`2`).
    /// @param user Address whose membership (if any) sets the fee tier.
    /// @return Fee in basis points passed to `BackingToken.buyFromRouter` / `refundFromRouter`.
    function getEffectiveFeeBps(uint8 productId, address user) public view returns (uint256) {
        require(productId < 3, "Invalid product ID");
        (, address nftAddr, ) = factory.products(productId);
        MembershipNFT nft = MembershipNFT(nftAddr);

        (uint8 highestTier, bool foundAny) = _highestMembershipTier(productId, user, nft);
        if (!foundAny) return BPS_NON_MEMBER;
        return _feeBpsForHighestTier(highestTier);
    }

    /// @notice Returns the highest tier held by `user` on `productId`, or `(0, false)` when they hold none.
    /// @dev Same resolution as `getEffectiveFeeBps` (cache when set, else scan).
    /// @param productId Factory product lane (`0`–`2`).
    /// @param user Address whose membership tier to resolve.
    /// @return highestTier Highest tier level (0=Bronze..4=Diamond); meaningless if `hasMembership == false`.
    /// @return hasMembership True iff `user` owns at least one NFT matching `productId`.
    function getUserTier(uint8 productId, address user)
        external
        view
        returns (uint8 highestTier, bool hasMembership)
    {
        require(productId < 3, "Invalid product ID");
        (, address nftAddr, ) = factory.products(productId);
        MembershipNFT nft = MembershipNFT(nftAddr);
        return _highestMembershipTier(productId, user, nft);
    }

    /// @notice Thrown when `factory.products(productId)` has no token registered.
    error ProductNotRegistered();

    /// @notice Buys IG through the router with tier-adjusted fee; pulls backing from `msg.sender`.
    /// @param productId Product lane in the factory.
    /// @param amount Backing amount to deposit.
    function buy(uint8 productId, uint256 amount) external nonReentrant {
        require(productId < 3, "Invalid product ID");
        (address tokenAddr, , ) = factory.products(productId);
        if (tokenAddr == address(0)) revert ProductNotRegistered();
        BackingToken token = BackingToken(tokenAddr);
        uint256 feeBps = getEffectiveFeeBps(productId, msg.sender);
        token.buyFromRouter(msg.sender, amount, feeBps);
    }

    /// @notice Redeems IG for backing through the router with tier-adjusted fee.
    /// @param productId Product lane in the factory.
    /// @param tokenAmount Amount of IG to burn.
    function refund(uint8 productId, uint256 tokenAmount) external nonReentrant {
        require(productId < 3, "Invalid product ID");
        (address tokenAddr, , ) = factory.products(productId);
        if (tokenAddr == address(0)) revert ProductNotRegistered();
        BackingToken token = BackingToken(tokenAddr);
        uint256 feeBps = getEffectiveFeeBps(productId, msg.sender);
        token.refundFromRouter(msg.sender, tokenAmount, feeBps);
    }
}

