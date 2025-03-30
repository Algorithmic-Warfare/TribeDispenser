import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "AWAR",
  systems: {
    TribeDispenserSystem: {
      name: "TribeDispenser",
      openAccess: true,
    },
    TribeStorageSystem: {
      name: "TribeStorage",
      openAccess: true,
    },
  },
  tables: {
    TribeStorageTransaction: {
      schema: {
        transactionId: "uint256",
        tribesmenAddress: "address",
        inventoryItemId: "uint256",
        inventoryItemAmount: "uint256",
        smartStorageUnitId: "uint256",
        timestamp: "uint256",
        transactionType: "StorageTransaction",
      },
      key: ["transactionId"],
    },
    TribePackage: {
      schema: {
        id: "uint256",
        author: "address",
        name: "string",
        entries: "uint256[]",
      },
      key: ["id"],
    },
    TribePackageEntries: {
      schema: {
        id: "uint256",
        packageId: "uint256",
        inventoryItemId: "uint256",
        inventoryItemAmount: "uint256",
      },
      key: ["id"],
    },
  },
  enums: {
    StorageTransaction: ["DEPOSIT", "WITHDRAWAL"],
  },
});
