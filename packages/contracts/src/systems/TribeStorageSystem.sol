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

/**
 * @title TribeStorageSystem
 * @dev A contract that manages the storage and retrieval of items within a tribe's collective inventory system.
 *      This contract ensures that only members of the same tribe (corporation) can interact with the storage units
 *      and perform deposit or withdrawal operations. It also maintains a record of all transactions for auditing purposes.
 *
 * @notice The contract uses various utility libraries to manage inventory, entities, and smart deployables.
 *
 * Features:
 * - Tribe-based access control for storage units.
 * - Deposit and withdrawal of items between ephemeral and collective inventories.
 * - Transaction logging for all storage operations.
 *
 * Requirements:
 * - The caller must belong to the same tribe as the owner of the smart storage unit being accessed.
 * - The smart storage unit ID must exist in the ERC721 registry.
 *
 * Libraries Used:
 * - InventoryLib: For managing inventory operations.
 * - EntityRecordUtils: For handling entity-related utilities.
 * - InventoryUtils: For inventory-specific utilities.
 * - SmartDeployableUtils: For managing smart deployable entities.
 * - SmartCharacterUtils: For managing smart character entities.
 *
 * Modifiers:
 * - `isTribesmen`: Ensures that the caller belongs to the same tribe as the owner of the specified smart storage unit.
 *
 * Functions:
 * - `depositAll`: Allows tribesmen to deposit all items from their ephemeral inventory into the collective inventory.
 * - `deposit`: Allows tribesmen to deposit a specific item and amount into the collective inventory.
 * - `withdraw`: Allows tribesmen to withdraw a specific item and amount from the collective inventory.
 * - `__depositToInventory`: Handles the internal logic for depositing items into the collective inventory.
 * - `__withdrawFromInventory`: Handles the internal logic for withdrawing items from the collective inventory.
 * - `smartCharacterAddressFromSmartStorageUnitId`: Retrieves the address of the smart character associated with a given smart storage unit ID.
 *
 * Transaction Logging:
 * - Each deposit and withdrawal operation generates a unique transaction ID based on the current block timestamp,
 *   smart storage unit ID, caller address, item ID, and item amount.
 * - Transaction details are stored in the `TribeStorageTransaction` table for record-keeping.
 *
 * Error Handling:
 * - Reverts with "Not allowed to access." if the caller does not belong to the same tribe as the smart storage unit owner.
 * - Reverts with "Smart Storage Unit ID does not exist." if the specified smart storage unit ID is invalid.
 * - Reverts with "Namespace is invalid" if the ERC721 namespace is improperly configured.
 */
contract TribeStorageSystem is System {
  using InventoryLib for InventoryLib.World;
  using EntityRecordUtils for bytes14;
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;

  InventoryLib.World inventory;

  // TODO define some failure modes.

  /**
   * @dev Modifier to check if the caller belongs to the same tribe as the owner of the specified Smart Storage Unit (SSU).
   *      Ensures that only members of the same corporation (tribe) can access certain functionality.
   *
   * @param smartStorageUnitId The ID of the Smart Storage Unit being accessed.
   *
   * Requirements:
   * - The caller must belong to the same corporation (tribe) as the owner of the Smart Storage Unit.
   *
   * Reverts with:
   * - "Not allowed to access." if the caller does not belong to the same corporation as the SSU owner.
   */
  modifier isTribesmen(uint256 smartStorageUnitId) {
    // checks if the caller is from the same tribe as the SSU owner.

    address smartStorageUnitOwnerAddress = smartCharacterAddressFromSmartStorageUnitId(smartStorageUnitId);
    uint256 ownerCharacterId = CharactersByAddressTable.getCharacterId(smartStorageUnitOwnerAddress);
    uint256 ownerCorpId = CharactersTable.getCorpId(ownerCharacterId);

    address tribesmenAddress = _msgSender();
    uint256 tribesmenCharacterId = CharactersByAddressTable.getCharacterId(tribesmenAddress);
    uint256 tribesmenCorpId = CharactersTable.getCorpId(tribesmenCharacterId);

    if (ownerCorpId != tribesmenCorpId) {
      revert("Not allowed to access.");
    }

    _;
  }

  /**
   * @notice Allows tribesmen to deposit all items from their ephemeral inventory into the collective inventory.
   * @dev This function iterates through the provided list of ephemeral inventory item IDs, retrieves their data,
   *      and deposits them into the collective inventory. A transaction record is created for each deposit.
   * @param smartStorageUnitId The ID of the smart storage unit associated with the tribesman.
   * @param ephemeralInventoryItemIds An array of item IDs from the ephemeral inventory to be deposited.
   * @dev The caller must be a tribesman associated with the specified smart storage unit.
   * @dev Each deposit operation generates a unique transaction ID based on the current block timestamp,
   *      smart storage unit ID, caller address, item ID, and item amount.
   * @dev The transaction details are stored in the TribeStorageTransaction table for record-keeping.
   */
  function depositAll(
    uint256 smartStorageUnitId,
    uint256[] memory ephemeralInventoryItemIds
  ) public isTribesmen(smartStorageUnitId) {
    for (uint256 i = 0; i < ephemeralInventoryItemIds.length; i++) {
      uint256 ephemeralInventoryItemId = ephemeralInventoryItemIds[i];

      EphemeralInvItemTableData memory itemToBeDeposited = EphemeralInvItemTable.get(
        smartStorageUnitId,
        ephemeralInventoryItemId,
        _msgSender()
      );
      // TODO grab the quantity
      uint256 ephemeralInventoryItemAmount = itemToBeDeposited.quantity;

      __depositToInventory(ephemeralInventoryItemId, ephemeralInventoryItemAmount, smartStorageUnitId);

      uint256 transactionId = uint256(
        keccak256(
          abi.encode(
            block.timestamp,
            smartStorageUnitId,
            _msgSender(),
            ephemeralInventoryItemId,
            ephemeralInventoryItemAmount
          )
        )
      );

      TribeStorageTransactionData memory transaction = TribeStorageTransactionData({
        timestamp: block.timestamp,
        tribesmenAddress: _msgSender(),
        inventoryItemId: ephemeralInventoryItemId,
        inventoryItemAmount: ephemeralInventoryItemAmount,
        smartStorageUnitId: smartStorageUnitId,
        transactionType: StorageTransaction.DEPOSIT
      });

      TribeStorageTransaction.set(transactionId, transaction);
    }
  }

  /**
   * @notice Allows a tribesman to deposit a specified amount of an inventory item into a smart storage unit.
   * @dev This function is restricted to tribesmen associated with the specified smart storage unit.
   *      It generates a unique transaction ID using a hash of the current block timestamp, the smart storage unit ID,
   *      the sender's address, the inventory item ID, and the inventory item amount.
   *      The transaction details are stored in the TribeStorageTransaction mapping.
   * @param smartStorageUnitId The ID of the smart storage unit where the inventory item will be deposited.
   * @param inventoryItemId The ID of the inventory item to be deposited.
   * @param inventoryItemAmount The amount of the inventory item to be deposited.
   * @custom:modifier isTribesmen Ensures that the caller is a tribesman associated with the specified smart storage unit.
   */
  function deposit(
    uint256 smartStorageUnitId,
    uint256 inventoryItemId,
    uint256 inventoryItemAmount
  ) public isTribesmen(smartStorageUnitId) {
    __depositToInventory(inventoryItemId, inventoryItemAmount, smartStorageUnitId);
    uint256 transactionId = uint256(
      keccak256(abi.encode(block.timestamp, smartStorageUnitId, _msgSender(), inventoryItemId, inventoryItemAmount))
    );

    TribeStorageTransactionData memory transaction = TribeStorageTransactionData({
      timestamp: block.timestamp,
      tribesmenAddress: _msgSender(),
      inventoryItemId: inventoryItemId,
      inventoryItemAmount: inventoryItemAmount,
      smartStorageUnitId: smartStorageUnitId,
      transactionType: StorageTransaction.DEPOSIT
    });

    TribeStorageTransaction.set(transactionId, transaction);
  }

  /**
   * @dev Handles the deposit of items into a smart storage unit's inventory.
   *
   * This private function facilitates the transfer of a specified item and its amount
   * from the sender's ephemeral storage to the inventory of a designated smart storage unit.
   *
   * @param transactionItemId The ID of the item being deposited into the inventory.
   * @param transactionItemAmount The amount of the item being deposited.
   * @param smartStorageUnitId The ID of the smart storage unit where the item will be stored.
   */
  function __depositToInventory(
    uint256 transactionItemId,
    uint256 transactionItemAmount,
    uint256 smartStorageUnitId
  ) private {
    inventory = InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });

    address source = _msgSender();
    // address recipient = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartStorageUnitId);

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(transactionItemId, source, transactionItemAmount);

    inventory.ephemeralToInventoryTransfer(smartStorageUnitId, transferItems);
  }

  /**
   * @notice Allows a tribesman to withdraw items from the collective inventory into their ephemeral inventory.
   * @dev This function is restricted to tribesmen associated with the specified smart storage unit.
   *      It records the withdrawal transaction in the TribeStorageTransaction mapping.
   * @param smartStorageUnitId The ID of the smart storage unit from which the items are being withdrawn.
   * @param inventoryItemId The ID of the inventory item to withdraw.
   * @param inventoryItemAmount The amount of the inventory item to withdraw.
   * @custom:requirements The caller must be a tribesman associated with the specified smart storage unit.
   * @custom:events A withdrawal transaction is recorded with a unique transaction ID.
   */
  function withdraw(
    uint256 smartStorageUnitId,
    uint256 inventoryItemId,
    uint256 inventoryItemAmount
  ) public isTribesmen(smartStorageUnitId) {
    __withdrawFromInventory(inventoryItemId, inventoryItemAmount, smartStorageUnitId);
    uint256 transactionId = uint256(
      keccak256(abi.encode(block.timestamp, smartStorageUnitId, _msgSender(), inventoryItemId, inventoryItemAmount))
    );

    TribeStorageTransactionData memory transaction = TribeStorageTransactionData({
      timestamp: block.timestamp,
      tribesmenAddress: _msgSender(),
      inventoryItemId: inventoryItemId,
      inventoryItemAmount: inventoryItemAmount,
      smartStorageUnitId: smartStorageUnitId,
      transactionType: StorageTransaction.WITHDRAWAL
    });

    TribeStorageTransaction.set(transactionId, transaction);
  }

  /**
   * @dev Withdraws a specified amount of an item from the inventory of a smart storage unit
   *      and transfers it to the caller's address.
   *
   * @param transactionItemId The ID of the item to be withdrawn from the inventory.
   * @param transactionItemAmount The amount of the item to be withdrawn.
   * @param smartStorageUnitId The ID of the smart storage unit from which the item will be withdrawn.
   *
   * @notice This function is private and can only be called within the contract.
   * @notice The caller must be the recipient of the withdrawn items.
   * @notice The smart storage unit must be owned by the source address.
   */
  function __withdrawFromInventory(
    uint256 transactionItemId,
    uint256 transactionItemAmount,
    uint256 smartStorageUnitId
  ) private {
    inventory = InventoryLib.World({ iface: IBaseWorld(_world()), namespace: FRONTIER_WORLD_DEPLOYMENT_NAMESPACE });

    address recepient = _msgSender();
    address source = IERC721(DeployableTokenTable.getErc721Address()).ownerOf(smartStorageUnitId);

    TransferItem[] memory transferItems = new TransferItem[](1);
    transferItems[0] = TransferItem(transactionItemId, source, transactionItemAmount);

    inventory.inventoryToEphemeralTransfer(smartStorageUnitId, recepient, transferItems);
  }

  /**
   * @dev Retrieves the address of the smart character associated with a given smart storage unit ID.
   *
   * This function uses the ERC721 registry to look up the owner of the specified smart storage unit ID.
   * It assumes that the smart storage unit ID corresponds to an ERC721 token deployed under a specific namespace.
   *
   * @param smartStorageUnitId The ID of the smart storage unit for which the associated smart character address is to be retrieved.
   * @return smartCharacterAddress The address of the smart character that owns the specified smart storage unit.
   *
   * Requirements:
   * - The `smartStorageUnitId` must exist in the ERC721 registry.
   * - The ERC721 registry must be properly configured with the namespace "erc721deploybl".
   */
  function smartCharacterAddressFromSmartStorageUnitId(uint256 smartStorageUnitId) private returns (address) {
    bytes14 SMART_DEPLOYABLE_ERC721_NAMESPACE = "erc721deploybl";
    IERC721 erc721DeployableToken = IERC721(
      ERC721Registry.get(
        ERC721_REGISTRY_TABLE_ID,
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_ERC721_NAMESPACE)
      )
    );
    return erc721DeployableToken.ownerOf(smartStorageUnitId);
  }
}
