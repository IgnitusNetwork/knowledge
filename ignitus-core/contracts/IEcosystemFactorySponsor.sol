// SPDX-License-Identifier: BUSL-1.1

/*
Business Source License 1.1

Parameters
Licensor:              IGNITUS NETWORK
Licensed Work:         Ecosystem Factory Sponsor Interface
Additional Use Grant:  You may make use of the Licensed Work for auditing, testing, and non-production purposes only.
Change Date:           2031-05-01
Change License:        Apache License, Version 2.0

For information about alternative licensing arrangements for the Licensed Work,
please contact through official channels of IGNITUS NETWORK.

Full license text: https://mariadb.com/bsl11/
*/
pragma solidity ^0.8.30;

/// @notice Minimal view for cross-product membership sponsor checks (avoids circular imports).
interface IEcosystemFactorySponsor {
    /// @return true if `sponsor` holds at least one membership NFT on any registered product (slots 0-2).
    function sponsorHasAnyMembership(address sponsor) external view returns (bool);
}

