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

import { PingTest, TribeStorageTransaction, TribeStorageTransactionData } from "../codegen/index.sol";

import { StorageTransaction } from "../codegen/common.sol";

/**
 * @dev This contract is an example for extending Inventory functionality from game.
 * This contract implements item trade as a feature to the existing inventoryIn logic
 */
contract TribeStorageSystem is System {
  using InventoryLib for InventoryLib.World;
  using EntityRecordUtils for bytes14;
  using InventoryUtils for bytes14;
  using SmartDeployableUtils for bytes14;
  using SmartCharacterUtils for bytes14;

  InventoryLib.World inventory;

  // TODO define some failure modes.

  modifier isTribesmen(uint256 smartStorageUnitId) {
    // TODO checks if the caller is from the same tribe as the SSU owner.

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

  function ping(string memory pingText) public {
    PingTest.set(_msgSender(), block.timestamp, pingText);
  }

  // NOTE this enables tribesmen to store items loaded in the ephemeral inveotry into the COLLECTIVE inventory
  function deposit(
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

  // NOTE this enables tribesmen to loot items from the COLLECTIVE inventory into their ephemeral inventory
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

  function smartCharacterAddressFromSmartStorageUnitId(uint256 smartStorageUnitId) internal returns (address) {
    bytes14 SMART_DEPLOYABLE_ERC721_NAMESPACE = "erc721deploybl";
    IERC721 erc721DeployableToken = IERC721(
      ERC721Registry.get(
        ERC721_REGISTRY_TABLE_ID,
        WorldResourceIdLib.encodeNamespace(SMART_DEPLOYABLE_ERC721_NAMESPACE)
      )
    );
    address smartCharacterAddress = erc721DeployableToken.ownerOf(smartStorageUnitId);
    return smartCharacterAddress;
  }
}
