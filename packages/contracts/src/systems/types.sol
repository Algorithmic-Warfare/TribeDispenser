// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/**
 * @dev Represents a package containing multiple entries.
 *      This struct is used to group related `PackageEntry` items together.
 *
 * @member entries An array of `PackageEntry` structs that are part of this package.
 */
struct Package {
  PackageEntry[] entries;
}

/**
 * @dev Represents an entry in a package, containing an item ID and its quantity.
 * @param itemId The unique identifier of the item in the package.
 * @param quantity The number of items of the specified type in the package.
 */
struct PackageEntry {
  uint256 itemId;
  uint256 quantity;
}
