//SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";

import { DEPLOYMENT_NAMESPACE, PRIMARY_SYSTEM_NAME, SECONDARY_SYSTEM_NAME } from "./constants.sol";

library Utils {
  /**
   * @dev Returns the unique identifier (ResourceId) for the Tribe Dispenser System.
   * This identifier is encoded using the `WorldResourceIdLib.encode` function,
   * which combines the type ID, namespace, and name of the system.
   *
   * @return ResourceId The encoded identifier for the Tribe Dispenser System.
   */
  function tribeDispenserSystemId() internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: DEPLOYMENT_NAMESPACE,
        name: PRIMARY_SYSTEM_NAME
      });
  }

  /**
   * @dev Returns the ResourceId for the tribe storage system.
   * This function encodes the resource ID using the `WorldResourceIdLib.encode` method
   * with the following parameters:
   * - `typeId`: Represents the type of resource, set to `RESOURCE_SYSTEM`.
   * - `namespace`: Represents the deployment namespace, set to `DEPLOYMENT_NAMESPACE`.
   * - `name`: Represents the secondary system name, set to `SECONDARY_SYSTEM_NAME`.
   *
   * @return ResourceId The encoded resource ID for the tribe storage system.
   */
  function tribeStorageSystemId() internal pure returns (ResourceId) {
    return
      WorldResourceIdLib.encode({
        typeId: RESOURCE_SYSTEM,
        namespace: DEPLOYMENT_NAMESPACE,
        name: SECONDARY_SYSTEM_NAME
      });
  }
}
