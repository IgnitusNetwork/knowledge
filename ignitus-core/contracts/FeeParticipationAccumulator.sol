// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Fee Participation Accumulator Smart Contracts
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MembershipNFT.sol";
import "./IMembershipBackingToken.sol";

/// @title FeeParticipationAccumulator
/// @notice Distributes a share of protocol fees to IG token holders using a reward-per-token accumulator; eligible balance is capped by `MembershipNFT` tier per product.
/// @dev Only the configured backing token may call `depositFees` and `updateUserReward`. Circulating supply excludes tokens held by this contract.
contract FeeParticipationAccumulator {
    using SafeERC20 for IERC20;

    /// @notice IG (or backing) ERC-20 whose transfers trigger reward snapshots via the token’s `_update` hook.
    IMembershipBackingToken public immutable token;
    /// @notice Membership NFT used to read per-wallet fee caps for `productId`.
    MembershipNFT public immutable nftContract;
    /// @notice Product lane; caps from NFTs with matching `productId` apply.
    uint8 public immutable productId;

    /// @dev Membership is sequential Bronze→Diamond (5 tiers); each upgrade mints and keeps the prior NFT, so at most 5 tokens per `productId` per wallet. We only consider `data.productId == productId`, so the relevant set is capped at 5, not 3×5 across products.
    uint256 internal constant MAX_NFT_SCAN = 5;

    /// @notice Cumulative reward factor scaled by 1e18 (reward per eligible token unit).
    uint256 public rewardPerTokenStored;
    /// @notice Running total of fee amounts credited through `depositFees`.
    uint256 public totalFeesDistributed;

    /// @notice Last `rewardPerTokenStored` applied when the user’s rewards were snapshotted.
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @notice Frozen claimable amount after `updateUserReward` until the next accrual is merged in `pendingRewards`.
    mapping(address => uint256) public claimableBalance;

    /// @notice Emitted when the backing token deposits fee tokens into the pool.
    event FeeDeposited(uint256 amount);
    /// @notice Emitted when a user claims accrued rewards.
    event Claimed(address indexed user, uint256 amount);

    /// @param _token Backing / IG token contract (must call this accumulator on fee deposits and transfers).
    /// @param _nftContract Membership NFT for cap lookup.
    /// @param _productId Product id this accumulator instance serves.
    constructor(address _token, address _nftContract, uint8 _productId) {
        token = IMembershipBackingToken(_token);
        nftContract = MembershipNFT(_nftContract);
        productId = _productId;
    }

    /// @notice Accepts fee tokens already transferred to this contract; increases `rewardPerTokenStored` over circulating supply.
    /// @dev Callable only by `token`. No-op if `amount` is zero.
    /// @param amount Token amount to accrue (matches the fee leg credited to this contract).
    function depositFees(uint256 amount) external {
        require(msg.sender == address(token), "Only token");
        if (amount == 0) return;

        IERC20 ig = IERC20(address(token));
        uint256 total = ig.totalSupply();
        uint256 inPool = ig.balanceOf(address(this));
        require(total > inPool, "No circulating supply");
        uint256 circSupply = total - inPool;
        rewardPerTokenStored += (amount * 1e18) / circSupply;
        totalFeesDistributed += amount;
        emit FeeDeposited(amount);
    }

    /// @notice Returns total claimable rewards for `user` including snapshot and pending accrual against the cap.
    /// @param user Holder of IG tokens.
    /// @return Total tokens claimable if `claim` were called now.
    function pendingRewards(address user) public view returns (uint256) {
        uint256 userBalance = IERC20(address(token)).balanceOf(user);
        uint256 cap = _getUserCap(user);
        uint256 eligible = userBalance > cap ? cap : userBalance;
        uint256 pending = (eligible * (rewardPerTokenStored - userRewardPerTokenPaid[user])) / 1e18;
        return claimableBalance[user] + pending;
    }

    /// @notice Transfers accrued rewards to `msg.sender` and resets their reward debt.
    function claim() external {
        uint256 reward = pendingRewards(msg.sender);
        if (reward == 0) return;

        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        claimableBalance[msg.sender] = 0;

        IERC20 ig = IERC20(address(token));
        uint256 bal = ig.balanceOf(address(this));
        require(bal >= reward, "Insufficient pool balance");
        ig.safeTransfer(msg.sender, reward);
        emit Claimed(msg.sender, reward);
    }

    /// @dev Maximum IG balance eligible for rewards for this product, derived from the user’s highest matching `MembershipNFT.tokenCap`.
    function _getUserCap(address user) internal view returns (uint256) {
        (bool cacheValid,, uint256 cachedCap) = nftContract.getTierScanCache(productId, user);
        if (cacheValid) {
            return cachedCap;
        }

        // The loop is naturally safe: each `MembershipNFT` contract is per-product and a user can hold
        // at most 5 soulbound NFTs on it (one per tier Bronze→Diamond). `MAX_NFT_SCAN = 5` is kept as
        // an explicit belt-and-braces cap in case the tier model is ever extended in the future.
        // `unchecked { ++i; }` is safe because `i` is bounded by `MAX_NFT_SCAN`.
        MembershipNFT nft = nftContract;
        uint256 balance = nft.balanceOf(user);
        uint256 scanLimit = balance > MAX_NFT_SCAN ? MAX_NFT_SCAN : balance;
        uint256 maxCap = 0;
        uint8 pid = productId;
        for (uint256 i = 0; i < scanLimit; ) {
            uint256 tokenId = nft.tokenOfOwnerByIndex(user, i);
            MembershipNFT.Membership memory data = nft.getMembership(tokenId);
            if (data.productId == pid) {
                uint256 cap = data.tokenCap;
                if (cap > maxCap) maxCap = cap;
                if (data.tierLevel == 4) break; // Diamond: highest tier, can't be beaten.
            }
            unchecked {
                ++i;
            }
        }
        return maxCap;
    }

    /// @notice Snapshots `user` rewards to `claimableBalance` and aligns paid index (called by the token on balance changes).
    /// @dev Callable only by `token`.
    /// @param user Account whose reward state to refresh.
    function updateUserReward(address user) external {
        require(msg.sender == address(token), "Only token");
        claimableBalance[user] = pendingRewards(user);
        userRewardPerTokenPaid[user] = rewardPerTokenStored;
    }
}

