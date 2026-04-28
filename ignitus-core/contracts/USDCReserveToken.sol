// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         USDC Reserve Token Smart Contracts
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IMembershipBackingToken.sol";
import "./IFeeParticipationAccumulator.sol";

/// @title USDCReserveToken
/// @notice IG-style ERC-20 backed by USDC: mint on buy, burn on refund; 1% trade fee split into backing boost, pool, and treasury legs.
/// @dev Transfers incur no fee. Fee pool/treasury legs mint IG while USDC remains in the vault; `MembershipNFT` is expected to be `onlyOwner`.
contract USDCReserveToken is ERC20, Ownable2Step, ReentrancyGuard, IMembershipBackingToken {
    using SafeERC20 for IERC20;

    /// @notice Underlying USDC (6 decimals) held as reserve.
    IERC20 public immutable USDC;
    /// @notice Recipient of treasury fee leg, credited as minted IG.
    address public treasury;
    /// @notice Fee participation pool; receives minted IG and `depositFees` on the accumulator.
    address public feeParticipationPool;

    /// @notice Protocol fee on buy/refund (100 bps = 1%).
    uint256 public constant FEE_BPS = 100;
    /// @notice Share of the fee (bps) kept as extra USDC backing (not withdrawn on refund path).
    uint256 public constant BACKING_BOOST_BPS = 50;
    /// @notice Share of the fee (bps) attributed to the pool leg for IG mint pricing.
    uint256 public constant POOL_BPS = 30;
    /// @notice Share of the fee (bps) attributed to the treasury leg.
    uint256 public constant TREASURY_BPS = 20;
    /// @notice Denominator for basis-point math.
    uint256 public constant BPS_DIVISOR = 10_000;

    /// @notice Minimum USDC amount for `buy` (1_000 = 0.001 USDC at 6 decimals).
    uint256 public constant MIN_AMOUNT = 1_000;
    /// @notice Minimum IG amount for `refund`. IG is 18 decimals; 0.001 IG is the always-correct floor.
    uint256 public constant MIN_IG_AMOUNT = 0.001 ether;
    /// @notice Total USDC economically attributed to backing (vault invariant checked on refund).
    uint256 public totalUSDCBacking;

    /// @dev IG minted for a fee leg given post-fee virtual backing `V` and supply `S` (ceil rounding).
    function _feePoolIgFromBackingShare(uint256 poolShare, uint256 V, uint256 S) internal pure returns (uint256) {
        if (poolShare == 0) return 0;
        uint256 denom = V - poolShare;
        require(denom > 0, "Pool share gte backing");
        return Math.mulDiv(poolShare, S, denom, Math.Rounding.Ceil);
    }

    /// @notice Emitted after a successful `buy`.
    event Bought(address indexed buyer, uint256 usdcIn, uint256 tokensOut);
    /// @notice Emitted after a successful `refund`.
    event Refunded(address indexed seller, uint256 tokensIn, uint256 usdcOut);
    /// @notice Emitted when owner updates `treasury`.
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    /// @notice Emitted when owner updates `feeParticipationPool`.
    event FeePoolUpdated(address oldPool, address newPool);
    /// @notice Emitted with the backing-boost component of the buy fee (USDC units).
    event BackingBoosted(uint256 addedUSDC);
    /// @notice Emitted for each recipient of `mintForMembership`.
    event MintForMembership(address indexed to, uint256 tokensMinted);

    /// @param _usdc USDC token address.
    /// @param _initialTreasury Initial treasury (non-zero).
    /// @param _initialFeePool Initial accumulator / pool (non-zero).
    /// @param name_ ERC-20 name.
    /// @param symbol_ ERC-20 symbol.
    constructor(
        address _usdc,
        address _initialTreasury,
        address _initialFeePool,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(_usdc != address(0) && _initialTreasury != address(0) && _initialFeePool != address(0), "Zero address");
        USDC = IERC20(_usdc);
        treasury = _initialTreasury;
        feeParticipationPool = _initialFeePool;
    }

    /// @notice Pulls USDC from `msg.sender`, mints IG at the current pool price (or bootstrap), splits fee into boost / pool / treasury legs.
    /// @param usdcAmount Gross USDC deposited (6 decimals).
    function buy(uint256 usdcAmount) external nonReentrant {
        require(usdcAmount >= MIN_AMOUNT, "Amount too small");
        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Fee on backing; userBacking is the economic value for mint-at-price
        uint256 feeBacking = (usdcAmount * FEE_BPS) / BPS_DIVISOR;
        uint256 userBacking = usdcAmount - feeBacking;

        uint256 V = totalUSDCBacking;
        uint256 S = totalSupply();

        uint256 tokensToUser;
        if (S == 0 || V == 0) {
            // Bootstrap: map USDC units to tokens at baseline
            tokensToUser = (userBacking * 1e18) / 1e6;
        } else {
            // Mint at current price: T = userBacking * S / V
            tokensToUser = (userBacking * S) / V;
        }

        // Full amount backs the system before fee distribution; track post-update totals in
        // locals so the fee-pool/treasury legs don't re-read storage.
        uint256 newV = V + usdcAmount;
        totalUSDCBacking = newV;
        _mint(msg.sender, tokensToUser);
        uint256 newS = S + tokensToUser;

        // Split feeBacking 50/30/20: backing boost, pool, treasury
        uint256 backingBoostUSDC = (feeBacking * BACKING_BOOST_BPS) / BPS_DIVISOR;
        uint256 poolUSDC = (feeBacking * POOL_BPS) / BPS_DIVISOR;
        uint256 treasuryUSDC = (feeBacking * TREASURY_BPS) / BPS_DIVISOR;
        // backingBoostUSDC conceptually remains in totalUSDCBacking

        address pool = feeParticipationPool;
        // 30% pool leg as ig minted to fee pool (USDC stays in vault)
        if (poolUSDC > 0 && pool != address(0)) {
            uint256 poolIg = _feePoolIgFromBackingShare(poolUSDC, newV, newS);
            if (poolIg > 0) {
                _mint(pool, poolIg);
                newS += poolIg;
                IFeeParticipationAccumulator(pool).depositFees(poolIg);
            }
        }
        // 20% treasury leg as ig minted to treasury (USDC stays in vault)
        if (treasuryUSDC > 0) {
            uint256 treasuryIg = _feePoolIgFromBackingShare(treasuryUSDC, newV, newS);
            if (treasuryIg > 0) _mint(treasury, treasuryIg);
        }

        emit Bought(msg.sender, usdcAmount, tokensToUser);
        emit BackingBoosted(backingBoostUSDC);
    }

    /// @notice Burns IG from `msg.sender` and sends net USDC; fee leg mints pool/treasury IG like `buy`.
    /// @param tokenAmount Amount of IG to redeem (18 decimals); subject to minimum scaled from `MIN_AMOUNT`.
    function refund(uint256 tokenAmount) external nonReentrant {
        require(tokenAmount >= MIN_IG_AMOUNT, "Amount too small");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient balance");

        uint256 V = totalUSDCBacking;
        uint256 S = totalSupply();

        // Gross backing value at current price: G = T * V / S
        uint256 usdcGross = (tokenAmount * V) / S;

        // Fee on value; user receives netBacking, fee is split 50/30/20
        uint256 feeBacking = (usdcGross * FEE_BPS) / BPS_DIVISOR;
        uint256 usdcNet = usdcGross - feeBacking;

        require(USDC.balanceOf(address(this)) >= usdcNet, "Insufficient backing");

        // Track post-update totals in locals so the fee-pool/treasury legs don't re-read storage.
        uint256 newV = V - usdcNet;  // feeBacking remains as backing before transfers out
        totalUSDCBacking = newV;
        _burn(msg.sender, tokenAmount);
        uint256 newS = S - tokenAmount;

        // Fee split on sell (same as buy), based on feeBacking (backing boost remains in totalUSDCBacking)
        uint256 poolUSDC = (feeBacking * POOL_BPS) / BPS_DIVISOR;
        uint256 treasuryUSDC = (feeBacking * TREASURY_BPS) / BPS_DIVISOR;

        address pool = feeParticipationPool;
        if (poolUSDC > 0 && pool != address(0)) {
            uint256 poolIg = _feePoolIgFromBackingShare(poolUSDC, newV, newS);
            if (poolIg > 0) {
                _mint(pool, poolIg);
                newS += poolIg;
                IFeeParticipationAccumulator(pool).depositFees(poolIg);
            }
        }
        if (treasuryUSDC > 0) {
            uint256 treasuryIg = _feePoolIgFromBackingShare(treasuryUSDC, newV, newS);
            if (treasuryIg > 0) _mint(treasury, treasuryIg);
        }

        USDC.safeTransfer(msg.sender, usdcNet);

        emit Refunded(msg.sender, tokenAmount, usdcNet);
    }

    /// @notice Owner-only mint for membership splits (typically `MembershipNFT`); does not pull USDC.
    /// @param toCompany Company allocation recipient.
    /// @param toAffiliate Affiliate allocation recipient.
    /// @param companyAmount IG minted to company.
    /// @param affiliateAmount IG minted to affiliate.
    function mintForMembership(address toCompany, address toAffiliate, uint256 companyAmount, uint256 affiliateAmount) 
        external onlyOwner 
    {
        require(toCompany != address(0) && toAffiliate != address(0), "Zero address");
        _mint(toCompany, companyAmount);
        _mint(toAffiliate, affiliateAmount);
        emit MintForMembership(toCompany, companyAmount);
        emit MintForMembership(toAffiliate, affiliateAmount);
    }

    /// @notice Increases `totalUSDCBacking` when membership payment is credited to the vault (no IG mint here).
    /// @param amount USDC units to add to backing accounting.
    function addBackingFromMembership(uint256 amount) external onlyOwner {
        totalUSDCBacking += amount;
    }

    /// @notice Updates treasury address.
    /// @param newTreasury New treasury (non-zero).
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Zero address");
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    /// @notice Updates fee participation pool / accumulator address.
    /// @param newPool New pool (non-zero).
    function setFeeParticipationPool(address newPool) external onlyOwner {
        require(newPool != address(0), "Zero address");
        emit FeePoolUpdated(feeParticipationPool, newPool);
        feeParticipationPool = newPool;
    }

    /// @notice Implied USDC per 1e18 IG (zero if no supply).
    /// @return USDC-denominated price scaled by 1e18.
    function getPricePerToken() external view returns (uint256) {
        uint256 S = totalSupply();
        return S == 0 ? 0 : (totalUSDCBacking * 1e18) / S;
    }

    /// @notice Backing per token as a fixed-point ratio (1e18 = 1:1 when fully backed at current accounting).
    function backingRatio() external view returns (uint256) {
        uint256 S = totalSupply();
        return S == 0 ? 1e18 : (totalUSDCBacking * 1e18) / S;
    }

    /// @inheritdoc IMembershipBackingToken
    function backingAsset() external view returns (IERC20) {
        return USDC;
    }

    /// @inheritdoc IMembershipBackingToken
    function backingDecimals() external pure returns (uint256) {
        return 6;
    }

    /// @inheritdoc IMembershipBackingToken
    function startingPriceUsd6() external pure returns (uint256) {
        return 1_000_000;
    }

    /// @inheritdoc IMembershipBackingToken
    function totalBacking() external view returns (uint256) {
        return totalUSDCBacking;
    }

    /// @dev Notifies the fee accumulator on balance changes for reward accounting.
    ///      Order matters: `updateUserReward` MUST run before `super._update` so the accumulator
    ///      snapshots rewards against the **pre-transfer** balance (Synthetix-style). See
    ///      `BackingToken._update` for rationale.
    function _update(address from, address to, uint256 value) internal override {
        address pool = feeParticipationPool;
        if (pool != address(0)) {
            if (from != address(0)) IFeeParticipationAccumulator(pool).updateUserReward(from);
            if (to != address(0)) IFeeParticipationAccumulator(pool).updateUserReward(to);
        }
        super._update(from, to, value);
    }
}

