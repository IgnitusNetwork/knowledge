// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Backing Token Smart Contracts
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

/// @title BackingToken
/// @notice ERC-20 token minted when users deposit backing asset; redeemable pro-rata for backing, net of protocol fees.
/// @dev Fee portions are converted to additional token supply for the participation pool and treasury per internal pricing logic.
contract BackingToken is ERC20, Ownable2Step, ReentrancyGuard, IMembershipBackingToken {
    using SafeERC20 for IERC20;

    /// @notice Underlying asset (e.g. stablecoin) held as protocol backing.
    IERC20 public immutable backingAsset;
    /// @notice Decimal scale of `backingAsset` (for integrators; math uses raw token units).
    uint256 public immutable backingDecimals;
    /// @notice Recipient of treasury fee allocation, minted as tokens.
    address public treasury;
    /// @notice Fee participation pool; receives minted tokens and records rewards via `IFeeParticipationAccumulator`.
    address public feeParticipationPool;
    /// @notice Address allowed to call `buyFromRouter` / `refundFromRouter`.
    address public router;
    /// @notice Initial mint price denominator when supply is zero (USD 6-decimal semantics per deployment).
    uint256 public startingPriceUsd6;

    /// @notice Default fee in basis points (1%) when `effectiveFeeBps` is passed as zero.
    uint256 public constant DEFAULT_FEE_BPS = 100;
    /// @notice Backing-boost fee leg in bps; defined for parity with related tokens (unused in this contract).
    uint256 public constant BACKING_BOOST_BPS = 50;
    /// @notice Share of the fee (in bps) routed to the participation pool.
    uint256 public constant POOL_BPS = 30;
    /// @notice Share of the fee (in bps) routed to the treasury.
    uint256 public constant TREASURY_BPS = 20;
    /// @notice Denominator for basis-point math (100%).
    uint256 public constant BPS_DIVISOR = 10_000;

    /// @notice Minimum backing amount for a direct `buy` (router may use different policy via caller).
    uint256 public constant MIN_AMOUNT = 1_000;
    /// @notice Minimum IG amount for `refund`. IG is 18 decimals; 0.001 IG is an always-correct
    ///         floor independent of `backingDecimals` (replaces the prior `MIN_AMOUNT * 10**12`).
    uint256 public constant MIN_IG_AMOUNT = 0.001 ether;
    /// @notice Total backing asset units currently attributed to the pool (vault balance invariant is enforced on refund).
    uint256 public totalBacking;

    /// @notice Thrown when `feeBps` exceeds `BPS_DIVISOR`.
    error FeeBpsTooHigh();
    /// @notice Thrown when treasury fee share is non-zero but `treasury` is unset.
    error TreasuryNotSet();

    /// @notice Emitted after a successful purchase (mint) path.
    event Bought(address indexed buyer, uint256 inAmount, uint256 tokensOut, uint256 effectiveFeeBps);
    /// @notice Emitted after a successful refund (burn) path.
    event Refunded(address indexed seller, uint256 tokensIn, uint256 outAmount, uint256 effectiveFeeBps);
    /// @notice Emitted when owner updates `treasury` (via token owner, typically `MembershipNFT`).
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    /// @notice Emitted when owner updates `feeParticipationPool`.
    event FeePoolUpdated(address oldPool, address newPool);
    /// @notice Emitted when owner updates `router`.
    event RouterUpdated(address oldRouter, address newRouter);

    /// @param _backingAsset ERC-20 backing token address.
    /// @param _backingDecimals Decimal count of `_backingAsset`.
    /// @param _initialTreasury Initial treasury address (may be zero if no treasury fees yet).
    /// @param _initialFeePool Participation pool / accumulator contract.
    /// @param _router Router authorized for gated buy/refund.
    /// @param name_ ERC-20 name.
    /// @param symbol_ ERC-20 symbol.
    /// @param _startingPriceUsd6 Price scalar for first mint when `totalSupply` is zero.
    /// @param initialOwner Ownable admin.
    constructor(
        address _backingAsset,
        uint256 _backingDecimals,
        address _initialTreasury,
        address _initialFeePool,
        address _router,
        string memory name_,
        string memory symbol_,
        uint256 _startingPriceUsd6,
        address initialOwner
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        require(_startingPriceUsd6 > 0, "Zero starting price");
        backingAsset = IERC20(_backingAsset);
        backingDecimals = _backingDecimals;
        treasury = _initialTreasury;
        feeParticipationPool = _initialFeePool;
        router = _router;
        startingPriceUsd6 = _startingPriceUsd6;
    }

    /// @notice Restricts calls to `router`.
    modifier onlyRouter() {
        require(msg.sender == router, "Only router");
        _;
    }

    /// @notice Pulls backing from `user`, mints this token per pricing and fee rules.
    /// @param user Payer and mint recipient.
    /// @param amount Backing amount pulled from `user`.
    /// @param effectiveFeeBps Fee in basis points; `0` means `DEFAULT_FEE_BPS`.
    function buyFromRouter(address user, uint256 amount, uint256 effectiveFeeBps) external onlyRouter nonReentrant {
        _buyFrom(user, amount, effectiveFeeBps == 0 ? DEFAULT_FEE_BPS : effectiveFeeBps);
    }

    /// @notice Same as `buyFromRouter` but `msg.sender` is both payer and recipient, using `DEFAULT_FEE_BPS`.
    /// @param amount Backing amount to deposit.
    function buy(uint256 amount) external nonReentrant {
        _buyFrom(msg.sender, amount, DEFAULT_FEE_BPS);
    }

    /// @dev Converts a backing fee slice into minted token amount using post-deposit virtual pool size `V` and supply `S`.
    function _feePoolIgFromBackingShare(uint256 poolShare, uint256 V, uint256 S) internal pure returns (uint256) {
        if (poolShare == 0) return 0;
        uint256 denom = V - poolShare;
        require(denom > 0, "Pool share gte backing");
        return Math.mulDiv(poolShare, S, denom, Math.Rounding.Ceil);
    }

    /// @dev Updates `totalBacking`, mints user tokens, mints fee allocations to pool/treasury when configured.
    function _buyFrom(address user, uint256 amount, uint256 feeBps) internal {
        require(amount >= MIN_AMOUNT, "Too small");
        if (feeBps > BPS_DIVISOR) revert FeeBpsTooHigh();

        backingAsset.safeTransferFrom(user, address(this), amount);

        uint256 feeBacking = (amount * feeBps) / BPS_DIVISOR;
        uint256 userBacking = amount - feeBacking;

        uint256 V = totalBacking;
        uint256 S = totalSupply();

        uint256 tokensToUser;
        if (S == 0 || V == 0) {
            tokensToUser = userBacking * (1e18) / startingPriceUsd6;
        } else {
            tokensToUser = (userBacking * S) / V;
        }

        // Track post-update totals in locals so the fee-pool/treasury legs don't re-read storage.
        uint256 newV = V + amount;
        totalBacking = newV;
        _mint(user, tokensToUser);
        uint256 newS = S + tokensToUser;

        uint256 poolShare = (feeBacking * POOL_BPS) / BPS_DIVISOR;
        uint256 treasuryShare = (feeBacking * TREASURY_BPS) / BPS_DIVISOR;

        address pool = feeParticipationPool;
        if (poolShare > 0 && pool != address(0)) {
            uint256 poolIg = _feePoolIgFromBackingShare(poolShare, newV, newS);
            if (poolIg > 0) {
                _mint(pool, poolIg);
                newS += poolIg;
                IFeeParticipationAccumulator(pool).depositFees(poolIg);
            }
        }
        if (treasuryShare > 0) {
            address _treasury = treasury;
            if (_treasury == address(0)) revert TreasuryNotSet();
            uint256 treasuryIg = _feePoolIgFromBackingShare(treasuryShare, newV, newS);
            if (treasuryIg > 0) _mint(_treasury, treasuryIg);
        }

        emit Bought(user, amount, tokensToUser, feeBps);
    }

    /// @notice Burns `user`'s tokens and sends net backing out; fee leg minted to pool/treasury like buys.
    /// @param user Account whose tokens are burned.
    /// @param tokenAmount Amount of this token to redeem.
    /// @param effectiveFeeBps Fee in basis points; `0` means `DEFAULT_FEE_BPS`.
    function refundFromRouter(address user, uint256 tokenAmount, uint256 effectiveFeeBps) external onlyRouter nonReentrant {
        _refundFrom(user, tokenAmount, effectiveFeeBps == 0 ? DEFAULT_FEE_BPS : effectiveFeeBps);
    }

    /// @notice Same as `refundFromRouter` for `msg.sender` with `DEFAULT_FEE_BPS`.
    /// @param tokenAmount Amount of this token to redeem.
    function refund(uint256 tokenAmount) external nonReentrant {
        _refundFrom(msg.sender, tokenAmount, DEFAULT_FEE_BPS);
    }

    /// @dev Burns tokens, reduces `totalBacking` by net out, transfers backing to `user`, mints fee tokens to pool/treasury.
    function _refundFrom(address user, uint256 tokenAmount, uint256 feeBps) internal {
        require(tokenAmount >= MIN_IG_AMOUNT, "Too small");
        if (feeBps > BPS_DIVISOR) revert FeeBpsTooHigh();
        require(balanceOf(user) >= tokenAmount, "Insufficient");

        uint256 V = totalBacking;
        uint256 S = totalSupply();

        uint256 outGross = (tokenAmount * V) / S;

        uint256 feeBacking = (outGross * feeBps) / BPS_DIVISOR;
        uint256 outNet = outGross - feeBacking;

        require(backingAsset.balanceOf(address(this)) >= outNet, "Insufficient backing");

        // Track post-update totals in locals so the fee-pool/treasury legs don't re-read storage.
        uint256 newV = V - outNet;
        totalBacking = newV;
        _burn(user, tokenAmount);
        uint256 newS = S - tokenAmount;

        uint256 poolShare = (feeBacking * POOL_BPS) / BPS_DIVISOR;
        uint256 treasuryShare = (feeBacking * TREASURY_BPS) / BPS_DIVISOR;

        address pool = feeParticipationPool;
        if (poolShare > 0 && pool != address(0)) {
            uint256 poolIg = _feePoolIgFromBackingShare(poolShare, newV, newS);
            if (poolIg > 0) {
                _mint(pool, poolIg);
                newS += poolIg;
                IFeeParticipationAccumulator(pool).depositFees(poolIg);
            }
        }
        if (treasuryShare > 0) {
            address _treasury = treasury;
            if (_treasury == address(0)) revert TreasuryNotSet();
            uint256 treasuryIg = _feePoolIgFromBackingShare(treasuryShare, newV, newS);
            if (treasuryIg > 0) _mint(_treasury, treasuryIg);
        }

        backingAsset.safeTransfer(user, outNet);
        emit Refunded(user, tokenAmount, outNet, feeBps);
    }

    /// @notice Owner-only mint for membership allocations (does not pull backing here).
    /// @param toCompany Recipient of company allocation.
    /// @param toAffiliate Recipient of affiliate allocation.
    /// @param companyAmount Tokens minted to company.
    /// @param affiliateAmount Tokens minted to affiliate.
    function mintForMembership(address toCompany, address toAffiliate, uint256 companyAmount, uint256 affiliateAmount)
        external onlyOwner
    {
        require(toCompany != address(0) && toAffiliate != address(0), "Zero address");
        _mint(toCompany, companyAmount);
        _mint(toAffiliate, affiliateAmount);
    }

    /// @notice Increases `totalBacking` when membership payment is credited (e.g. after NFT sale); does not mint.
    /// @param amount Backing units to add to accounting.
    function addBackingFromMembership(uint256 amount) external onlyOwner {
        totalBacking += amount;
    }

    /// @notice Updates treasury recipient (fee + membership company leg). Non-zero required while fees mint to treasury.
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Zero address");
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }
    /// @notice Updates participation pool / accumulator address. Non-zero required; zeroing would silently
    ///         disable reward accrual on all transfers (the `_update` hook no-ops on `address(0)`).
    function setFeeParticipationPool(address newPool) external onlyOwner {
        require(newPool != address(0), "Zero address");
        emit FeePoolUpdated(feeParticipationPool, newPool);
        feeParticipationPool = newPool;
    }
    /// @notice Updates router for gated buy/refund entrypoints. Non-zero required.
    function setRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Zero address");
        emit RouterUpdated(router, newRouter);
        router = newRouter;
    }

    /// @notice Implied backing per 1e18 tokens (zero if no supply).
    /// @return Price in backing-per-token scaled by 1e18.
    function getPricePerToken() external view returns (uint256) {
        uint256 S = totalSupply();
        return S == 0 ? 0 : (totalBacking * 1e18) / S;
    }

    /// @dev Notifies the fee accumulator on balance changes so reward accounting stays consistent.
    ///      Order matters: `updateUserReward` MUST run before `super._update` so the accumulator
    ///      snapshots rewards against the **pre-transfer** balance (Synthetix-style). Running after
    ///      `super._update` would let a new holder inherit historical `rewardPerTokenStored` on a
    ///      freshly credited balance, and rob the sender of accrual for the period they held.
    function _update(address from, address to, uint256 value) internal override {
        address pool = feeParticipationPool;
        if (pool != address(0)) {
            if (from != address(0)) IFeeParticipationAccumulator(pool).updateUserReward(from);
            if (to != address(0)) IFeeParticipationAccumulator(pool).updateUserReward(to);
        }
        super._update(from, to, value);
    }
}

