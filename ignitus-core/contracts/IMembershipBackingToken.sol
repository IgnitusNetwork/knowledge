// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Membership Backing Token Interface
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IMembershipBackingToken
 * @dev Interface for token + vault used by MembershipNFT and FeeParticipationAccumulator.
 *      Implemented by USDCReserveToken and BackingToken (USDC, Gold, WBTC products).
 */
interface IMembershipBackingToken {
  function backingAsset() external view returns (IERC20);
  function backingDecimals() external view returns (uint256);
  function treasury() external view returns (address);
  function startingPriceUsd6() external view returns (uint256); // NEW: For parity bootstrap

  /// @dev Total backing value held by this token (used for price calculation).
  function totalBacking() external view returns (uint256);

  function mintForMembership(
    address toCompany,
    address toAffiliate,
    uint256 companyAmountTokens,
    uint256 affiliateAmountTokens
  ) external;

  /// @dev Called by NFT (owner) after receiving full membership payment so vault backing is updated
  function addBackingFromMembership(uint256 amountBacking) external;
}

