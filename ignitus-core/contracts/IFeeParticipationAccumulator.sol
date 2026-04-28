// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Fee Participation Accumulator Interface
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

/**
 * @title IFeeParticipationAccumulator
 * @dev Minimal interface for token contracts to call depositFees and updateUserReward.
 */
interface IFeeParticipationAccumulator {
    function depositFees(uint256 amount) external;
    function updateUserReward(address user) external;
}

