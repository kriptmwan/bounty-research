// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {SplitsWarehouse} from "splits-v2/SplitsWarehouse.sol";
import {PullSplit} from "splits-v2/splitters/pull/PullSplit.sol";
import {PushSplit} from "splits-v2/splitters/push/PushSplit.sol";
import {PullSplitFactory} from "splits-v2/splitters/pull/PullSplitFactory.sol";
import {PushSplitFactory} from "splits-v2/splitters/push/PushSplitFactory.sol";
import {SplitFactoryV2} from "splits-v2/splitters/SplitFactoryV2.sol";
import {SplitWalletV2} from "splits-v2/splitters/SplitWalletV2.sol";

contract SmokeTest is Test {
    function testCompileSmoke() public {
        SplitsWarehouse w = new SplitsWarehouse("Ether", "ETH");
        assertTrue(address(w) != address(0));
        // Reference the other contracts so the compiler must build them.
        assertTrue(type(PullSplit).creationCode.length > 0);
        assertTrue(type(PushSplit).creationCode.length > 0);
        assertTrue(type(PullSplitFactory).creationCode.length > 0);
        assertTrue(type(PushSplitFactory).creationCode.length > 0);
    }
}
