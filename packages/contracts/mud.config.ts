import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "AWAR",
  systems: {
    TribeStorageSystem: {
      name: "TribeStorage",
      openAccess: true,
    },
  },
  tables: {
    PingTest: {
      schema: {
        pingAddress: "address",
        pingTimestamp: "uint256",
        pingText: "string",
      },
      key: ["pingAddress"],
    },
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
  },
  enums: {
    StorageTransaction: ["DEPOSIT", "WITHDRAWAL"],
  },
});
