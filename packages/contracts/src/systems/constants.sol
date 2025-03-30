// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

/**
 * @dev Constant representing the deployment namespace for the system.
 * This value must match the namespace defined in the `mud.config.ts` file
 * to ensure consistency across the deployment configuration.
 *
 * Note: Update this constant if the namespace in `mud.config.ts` changes.
 */
bytes14 constant DEPLOYMENT_NAMESPACE = "AWAR";

/**
 * @dev Defines constant values for system names used in the contract.
 *
 * Constants:
 * - `PRIMARY_SYSTEM_NAME`: Represents the primary system name, "TribeDispenser".
 * - `SECONDARY_SYSTEM_NAME`: Represents the secondary system name, "TribeStorage".
 */
bytes16 constant PRIMARY_SYSTEM_NAME = "TribeDispenser";
bytes16 constant SECONDARY_SYSTEM_NAME = "TribeStorage";
