// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Aggregator: forces compilation of the four audit-target entry points from the
// read-only repo checkout (see remappings.txt: contracts/ -> repos/nexus/contracts/).
// It exists only so `forge build` compiles the Nexus code; tests import from
// "contracts/..." directly.
import { Nexus } from "contracts/Nexus.sol";
import { NexusBootstrap } from "contracts/utils/NexusBootstrap.sol";
import { LibPREP } from "contracts/lib/local/LibPREP.sol";
import { K1Validator } from "contracts/modules/validators/K1Validator.sol";
import { NexusProxy } from "contracts/utils/NexusProxy.sol";

/// @notice Empty anchor contract referencing the imported types so the imports
/// are not pruned; no logic lives here.
contract NexusAggregator {
    function anchor()
        external
        pure
        returns (
            bytes32 a,
            bytes32 b,
            bytes32 c,
            bytes32 d,
            bytes32 e
        )
    {
        a = keccak256(type(Nexus).creationCode);
        b = keccak256(type(NexusBootstrap).creationCode);
        c = keccak256(type(K1Validator).creationCode);
        d = keccak256(type(NexusProxy).creationCode);
        // LibPREP is an internal-only library; exercised via prepCheck below.
        e = bytes32(uint256(0));
        return (a, b, c, d, e);
    }

    /// @notice Thin wrapper proving LibPREP compiles and links.
    function prepCheck(address target, bytes32 r, address delegation) external view returns (bool) {
        return LibPREP.isValid(target, r, delegation);
    }
}
