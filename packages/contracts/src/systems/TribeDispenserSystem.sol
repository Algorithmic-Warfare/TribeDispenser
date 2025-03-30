// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";
import { console } from "forge-std/console.sol";
import { ResourceIds } from "@latticexyz/store/src/codegen/tables/ResourceIds.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { System } from "@latticexyz/world/src/System.sol";

import { IERC721 } from "@eveworld/world/src/modules/eve-erc721-puppet/IERC721.sol";
import { InventoryLib } from "@eveworld/world/src/modules/inventory/InventoryLib.sol";
import { InventoryItem } from "@eveworld/world/src/modules/inventory/types.sol";
import { IInventoryErrors } from "@eveworld/world/src/modules/inventory/IInventoryErrors.sol";

import { DeployableTokenTable } from "@eveworld/world/src/codegen/tables/DeployableTokenTable.sol";
import { InventoryItemTable } from "@eveworld/world/src/codegen/tables/InventoryItemTable.sol";
import { EphemeralInvTable } from "@eveworld/world/src/codegen/tables/EphemeralInvTable.sol";
import { EphemeralInvItemTable } from "@eveworld/world/src/codegen/tables/EphemeralInvItemTable.sol";
import { EntityRecordTable, EntityRecordTableData } from "@eveworld/world/src/codegen/tables/EntityRecordTable.sol";
import { EphemeralInvItemTableData, EphemeralInvItemTable } from "@eveworld/world/src/codegen/tables/EphemeralInvItemTable.sol";
import { InventoryItemTableData, InventoryItemTable } from "@eveworld/world/src/codegen/tables/InventoryItemTable.sol";
import { IERC721 } from "@eveworld/world/src/modules/eve-erc721-puppet/IERC721.sol";
import { ERC721Registry } from "@eveworld/world/src/codegen/tables/ERC721Registry.sol";
import { ERC721_REGISTRY_TABLE_ID } from "@eveworld/world/src/modules/eve-erc721-puppet/constants.sol";

import { DeployableTokenTable } from "@eveworld/world/src/codegen/tables/DeployableTokenTable.sol";
import { Utils as EntityRecordUtils } from "@eveworld/world/src/modules/entity-record/Utils.sol";
import { Utils as InventoryUtils } from "@eveworld/world/src/modules/inventory/Utils.sol";
import { Utils as SmartDeployableUtils } from "@eveworld/world/src/modules/smart-deployable/Utils.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { TransferItem } from "@eveworld/world/src/modules/inventory/types.sol";
import { Utils as SmartCharacterUtils } from "@eveworld/world/src/modules/smart-character/Utils.sol";
import { CharactersTableData, CharactersTable } from "@eveworld/world/src/codegen/tables/CharactersTable.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";

import { TribeStorageTransaction, TribeStorageTransactionData, TribePackage, TribePackageData, TribePackageEntries, TribePackageEntriesData } from "../codegen/index.sol";

import { StorageTransaction } from "../codegen/common.sol";
import { Package, PackageEntry } from "./types.sol";
import { TribeStorageSystem } from "./TribeStorageSystem.sol";

/**
 * @title TribeDispenserSystem
 * @dev This contract extends the TribeStorageSystem and provides functionality for managing and dispensing packages
 *      within a tribal system. It allows tribesmen to register, retrieve, rename, unregister, and dispense materials
 *      for packages. The contract interacts with various storage tables to manage package metadata and entries.
 *
 * Features:
 * - Register packages with metadata and entries.
 * - Retrieve package details and associated entries.
 * - Rename existing packages.
 * - Unregister packages and remove associated entries.
 * - Dispense materials for a specified package from the inventory.
 *
 * Dependencies:
 * - Uses libraries: InventoryLib, EntityRecordUtils, InventoryUtils, SmartDeployableUtils, SmartCharacterUtils.
 * - Interacts with storage tables: TribePackage, TribePackageEntries, InventoryItemTable.
 *
 * Functions:
 * - `registerPackage`: Registers a new package with metadata and entries.
 * - `getPackage`: Retrieves package details and associated entries by package ID.
 * - `renamePackage`: Renames an existing package.
 * - `unregisterPackage`: Unregisters a package and removes associated entries.
 * - `dispensePackageMaterials`: Dispenses materials required for a specified package from the inventory.
 *
 * Requirements:
 * - The caller must be a tribesman associated with the given smart storage unit.
 * - Packages must exist for operations like renaming, unregistering, and dispensing.
 * - Inventory must have sufficient materials for dispensing operations.
 *
 * Reverts:
 * - If the package does not exist.
 * - If the quantity for dispensing is zero or less.
 * - If the inventory does not have sufficient materials for the requested package and quantity.
 */
contract TribeDispenserSystem is TribeStorageSystem {
  using InventoryLib for InventoryLib.World;
  using EntityRecordUtils for bytes14;
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;

  /**
   * @notice Registers a new package in the system.
   * @dev This function allows a tribesman to register a package by providing its details.
   *      The package is split into individual entries, which are stored in the `TribePackageEntries` table.
   *      The package metadata, including its name and list of entry IDs, is stored in the `TribePackage` table.
   * @param smartStorageUnitId The ID of the smart storage unit associated with the tribesman.
   * @param packageName The name of the package being registered.
   * @param package The package details, including its entries (items and their quantities).
   * @dev The caller must be a tribesman associated with the given `smartStorageUnitId`.
   * @notice Steps:
   *         1. Each entry in the package is processed and stored in the `TribePackageEntries` table.
   *         2. The package metadata, including its name and list of entry IDs, is stored in the `TribePackage` table.
   */
  function registerPackage(
    uint256 smartStorageUnitId,
    string memory packageName,
    Package memory package
  ) public isTribesmen(smartStorageUnitId) {
    uint256 packageId = uint256(keccak256(abi.encode(block.timestamp, smartStorageUnitId, _msgSender(), packageName)));
    // Step 1. open the package content and read the packageEntries putting them in the TribePackageEntries table
    uint256[] memory entryIds = new uint256[](package.entries.length);
    for (uint256 i = 0; i < package.entries.length; i++) {
      PackageEntry memory entry = package.entries[i];
      uint256 entryId = uint256(keccak256(abi.encode(packageId, entry.itemId, entry.quantity, i)));

      TribePackageEntriesData memory packageEntryData = TribePackageEntriesData({
        packageId: packageId,
        inventoryItemId: entry.itemId,
        inventoryItemAmount: entry.quantity
      });

      TribePackageEntries.set(entryId, packageEntryData);
    }
    // Step 2. register the id, name, and list of packageEntryId in the TribePackage table
    TribePackageData memory packageData = TribePackageData({
      author: _msgSender(),
      name: packageName,
      entries: entryIds
    });

    TribePackage.set(packageId, packageData);
  }

  /**
   * @notice Retrieves a package and its associated entries based on the given package ID.
   * @dev This function fetches package data from the `TribePackage` contract and populates
   *      the package with its corresponding entries by querying the `TribePackageEntries` contract.
   * @param packageId The unique identifier of the package to retrieve.
   * @return A `Package` struct containing the list of entries, where each entry specifies
   *         an item ID and its corresponding quantity.
   */
  function getPackage(uint256 packageId) public view returns (Package memory) {
    // Step 1. grab the package entry from TribePackage using packageId
    TribePackageData memory packageData = TribePackage.get(packageId);
    // Step 2. populate package using the entries list
    uint256[] memory entryIds = packageData.entries;
    PackageEntry[] memory entries = new PackageEntry[](entryIds.length);

    for (uint256 i = 0; i < entryIds.length; i++) {
      TribePackageEntriesData memory entryData = TribePackageEntries.get(entryIds[i]);
      entries[i] = PackageEntry({ itemId: entryData.inventoryItemId, quantity: entryData.inventoryItemAmount });
    }
    return Package({ entries: entries });
  }

  /**
   * @notice Renames an existing package with a new name.
   * @dev This function checks if the package exists before renaming it.
   *      The package data is retrieved from the TribePackage table, and the name is updated.
   * @param packageId The unique identifier of the package to be renamed.
   * @param newPackageName The new name to assign to the package.
   * @dev Requires that the package must exist (i.e., its name must not be empty).
   */
  function renamePackage(uint256 packageId, string memory newPackageName) public {
    // Step 1. check if the package exists
    TribePackageData memory packageData = TribePackage.get(packageId);
    require(bytes(packageData.name).length > 0, "Package does not exist");

    // Step 2. rename the package in the MUD table
    packageData.name = newPackageName;
    TribePackage.set(packageId, packageData);
  }

  /**
   * @notice Unregisters a package by its ID, removing all associated entries and the package itself.
   * @dev This function performs the following steps:
   *      1. Retrieves the package data using the provided `packageId`.
   *         Ensures the package exists by checking that its name is not empty.
   *      2. Iterates through all entry IDs associated with the package and deletes
   *         each entry from the `TribePackageEntries` storage.
   *      3. Deletes the package record itself from the `TribePackage` storage.
   * @param packageId The unique identifier of the package to be unregistered.
   * @dev Requires that the package with the given `packageId` must exist.
   */
  function unregisterPackage(uint256 packageId) public {
    // Step 1. find package entry using packageId, and use the entry list to delete all package entries from TribePackageEntries
    TribePackageData memory packageData = TribePackage.get(packageId);
    require(bytes(packageData.name).length > 0, "Package does not exist");

    uint256[] memory entryIds = packageData.entries;
    for (uint256 i = 0; i < entryIds.length; i++) {
      TribePackageEntries.deleteRecord(entryIds[i]);
    }
    // Step 2. finally, delete the package row from TribePackage
    TribePackage.deleteRecord(packageId);
  }

  /**
   * @notice Dispenses materials required for a specified package from the inventory.
   * @dev This function ensures that the package exists, the quantity is valid,
   *      and the required materials are available in the inventory before transferring them.
   * @param smartStorageUnitId The ID of the smart storage unit associated with the inventory.
   * @param packageId The ID of the package to dispense materials for.
   * @param quantity The quantity of the package to dispense.
   *
   * Requirements:
   * - The caller must be a tribesman associated with the given smart storage unit.
   * - The packageId must correspond to an existing package.
   * - The quantity must be greater than zero.
   * - The inventory must have sufficient materials for the requested package and quantity.
   *
   * Steps:
   * 1. Validate that the packageId corresponds to an existing package.
   * 2. Ensure the quantity is greater than zero.
   * 3. Retrieve the material entries associated with the package.
   * 4. Verify that the inventory contains sufficient materials for each entry.
   * 5. Transfer the required materials from the inventory to the ephemeral inventory.
   *
   * Reverts:
   * - If the package does not exist.
   * - If the quantity is zero or less.
   * - If the inventory does not have sufficient materials for the requested package and quantity.
   */
  function dispensePackageMaterials(
    uint256 smartStorageUnitId,
    uint256 packageId,
    uint256 quantity
  ) public isTribesmen(smartStorageUnitId) {
    // Step 1: Check if the packageId is valid
    TribePackageData memory packageData = TribePackage.get(packageId);
    require(bytes(packageData.name).length > 0, "Package does not exist");

    // Step 2: Check if the quantity is valid
    require(quantity > 0, "Quantity must be greater than zero");

    // Step 3: Read the materials from the MUD table package
    uint256[] memory entryIds = packageData.entries;

    // Step 4: Check if the materials are available in the inventory
    for (uint256 i = 0; i < entryIds.length; i++) {
      TribePackageEntriesData memory entryData = TribePackageEntries.get(entryIds[i]);
      uint256 requiredAmount = entryData.inventoryItemAmount * quantity;

      uint256 availableAmount = InventoryItemTable.getQuantity(smartStorageUnitId, entryData.inventoryItemId);
      require(availableAmount >= requiredAmount, "Insufficient materials in inventory");
    }

    // Step 5: Transfer the materials to the ephemeral inventory
    for (uint256 i = 0; i < entryIds.length; i++) {
      TribePackageEntriesData memory entryData = TribePackageEntries.get(entryIds[i]);
      uint256 transferAmount = entryData.inventoryItemAmount * quantity;
      withdraw(smartStorageUnitId, entryData.inventoryItemId, transferAmount);
    }
  }
}
