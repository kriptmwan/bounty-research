// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import { Call, ISmartVault } from "src/interfaces/ISmartVault.sol";

/// @notice Faithful mock of the SmartVault account surface the modules rely on:
/// executeFromModule is onlyModule, enable/disableModule are only-self (via execute),
/// execute is only-owner-or-entrypoint. Mirrors the modifiers documented in ISmartVault.
contract MockVault is ISmartVault {
    address public immutable ENTRY_POINT;
    address private _owner;
    mapping(address => bool) private _modules;

    error OnlyModule();
    error OnlySelf();
    error OnlyOwnerOrEntryPoint();
    error CallFailed();

    constructor(address owner_, address entryPoint_) {
        _owner = owner_;
        ENTRY_POINT = entryPoint_;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function isModuleEnabled(address module_) external view returns (bool) {
        return _modules[module_];
    }

    function executeFromModule(Call[] calldata calls_) external {
        if (!_modules[msg.sender]) revert OnlyModule();
        for (uint256 i; i < calls_.length; ++i) {
            (bool ok,) = calls_[i].target.call{value: calls_[i].value}(calls_[i].data);
            if (!ok) revert CallFailed();
        }
    }

    function enableModule(address module_) external {
        if (msg.sender != address(this)) revert OnlySelf();
        _modules[module_] = true;
    }

    function disableModule(address module_) external {
        if (msg.sender != address(this)) revert OnlySelf();
        _modules[module_] = false;
    }

    function execute(Call calldata call_) external payable {
        if (msg.sender != _owner && msg.sender != ENTRY_POINT) revert OnlyOwnerOrEntryPoint();
        (bool ok,) = call_.target.call{value: call_.value}(call_.data);
        if (!ok) revert CallFailed();
    }

    receive() external payable { }
}
