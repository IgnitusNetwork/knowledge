// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Ecosystem Factory Smart Contracts
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./IEcosystemFactorySponsor.sol";

/// @notice Minimal ERC-721 balance check for registered product NFTs.
interface IERC721Balance {
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Marketing mint hook exposed by product membership NFT contracts.
interface IMembershipNFTMintMarketing {
    function mintMarketingBronze(uint8 productId, address recipient, address affiliateRecipient) external;
}

/// @notice Updates backing-token treasury through the product’s `MembershipNFT` (NFT is `onlyOwner` on the token).
interface IMembershipNFTSetTokenTreasury {
    function setTokenTreasury(address newTreasury) external;
}

/// @notice Minimal view interface on `FeeParticipationAccumulator` used for wiring cross-checks at registration.
interface IFeeAccumulatorView {
    function token() external view returns (address);
    function nftContract() external view returns (address);
    function productId() external view returns (uint8);
}

/// @title EcosystemFactory
/// @notice On-chain registry of deployed product triples (token, membership NFT, fee accumulator) for the Ignitus ecosystem.
/// @dev Kept small for L1 deployment limits. Contracts are deployed elsewhere, then wired via `registerProduct`.
contract EcosystemFactory is Ownable2Step, IEcosystemFactorySponsor {
    /// @notice Addresses for a single product lane (ids 0–2).
    struct Product {
        address token;
        address nft;
        address accumulator;
    }

    /// @notice Registered product by id; unset slots read as zero addresses.
    mapping(uint8 => Product) public products;
    /// @notice Treasury address fixed at deploy (used by deploy scripts / integrators).
    address public immutable initialTreasury;
    /// @notice Root affiliate address fixed at deploy (used by deploy scripts / integrators).
    address public immutable rootAffiliate;

    /// @notice Emitted when owner registers a product’s contracts.
    event ProductDeployed(uint8 indexed productId, address token, address nft, address accumulator);
    /// @notice Emitted when owner routes a new treasury on the product’s IG token (via membership NFT).
    event ProductTokenTreasuryUpdated(uint8 indexed productId, address newTreasury);

    /// @param _initialTreasury Protocol treasury recorded at construction.
    /// @param _rootAffiliate Root affiliate recorded at construction.
    constructor(address _initialTreasury, address _rootAffiliate) Ownable(msg.sender) {
        require(_initialTreasury != address(0) && _rootAffiliate != address(0), "Zero address");
        initialTreasury = _initialTreasury;
        rootAffiliate = _rootAffiliate;
    }

    /// @notice Registers or replaces the contract set for `productId` (must be unused slot).
    /// @param productId Lane index in `[0, 2]`.
    /// @param token Backing or product token address.
    /// @param nft Membership NFT contract for this product.
    /// @param accumulator Fee participation accumulator for this product.
    function registerProduct(uint8 productId, address token, address nft, address accumulator) external onlyOwner {
        require(productId < 3, "Product ID must be 0-2");
        require(products[productId].token == address(0), "Already deployed");
        require(token != address(0) && nft != address(0) && accumulator != address(0), "Zero address");
        // Soft defense-in-depth: ensure the accumulator was deployed pointing at this exact triple.
        // Catches copy-paste / parameter-order mistakes at registration since the slot is one-shot.
        require(IFeeAccumulatorView(accumulator).token() == token, "Accumulator token mismatch");
        require(IFeeAccumulatorView(accumulator).nftContract() == nft, "Accumulator NFT mismatch");
        require(IFeeAccumulatorView(accumulator).productId() == productId, "Accumulator product mismatch");
        products[productId] = Product(token, nft, accumulator);
        emit ProductDeployed(productId, token, nft, accumulator);
    }

    /// @inheritdoc IEcosystemFactorySponsor
    function sponsorHasAnyMembership(address sponsor) external view override returns (bool) {
        // Loop is fixed at 3 iterations (productIds 0..2), so `++i` cannot overflow.
        for (uint8 i = 0; i < 3; ) {
            Product storage p = products[i];
            if (p.nft != address(0) && IERC721Balance(p.nft).balanceOf(sponsor) > 0) {
                return true;
            }
            unchecked { ++i; }
        }
        return false;
    }

    /// @notice Owner-only marketing mint on the product’s NFT contract.
    /// @param productId Registered product lane.
    /// @param recipient Address receiving the marketing Bronze mint.
    /// @param affiliateRecipient Per `MembershipNFT.mintMarketingBronze` (anchor uses `address(0)`).
    function mintMarketingBronze(uint8 productId, address recipient, address affiliateRecipient) external onlyOwner {
        require(productId < 3, "Invalid product ID");
        Product storage p = products[productId];
        require(p.nft != address(0), "Product not deployed");
        IMembershipNFTMintMarketing(p.nft).mintMarketingBronze(productId, recipient, affiliateRecipient);
    }

    /// @notice Points the product IG token’s `treasury` to `newTreasury` (membership mint company leg + fee share). Factory owner only.
    /// @dev Call this before renouncing factory ownership if the final company wallet differs from deploy-time treasury.
    function setProductTokenTreasury(uint8 productId, address newTreasury) external onlyOwner {
        require(productId < 3, "Invalid product ID");
        require(newTreasury != address(0), "Zero address");
        Product storage p = products[productId];
        require(p.nft != address(0), "Product not deployed");
        IMembershipNFTSetTokenTreasury(p.nft).setTokenTreasury(newTreasury);
        emit ProductTokenTreasuryUpdated(productId, newTreasury);
    }
}

