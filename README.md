# Tribe Dispenser

The **Tribe Dispenser** is a smart contract-based system designed to manage and distribute recipes for tribes in a decentralized manner. This repository contains the necessary contracts and tools to deploy and interact with the system.

## Repository Structure

- **contracts/**: Contains the smart contracts that define the core functionality of the Tribe Recipe Dispenser.
- **scripts/**: Includes deployment and interaction scripts for the contracts.
- **test/**: Contains test cases to ensure the contracts work as expected.

## How to Use

### 1. Prerequisites
Follow the steps outlined in the [Eve Frontier Tools Documentation](https://docs.evefrontier.com/Tools) to set up your environment.

### 2. Installation
Clone the repository and install dependencies:
```bash
git clone https://github.com/your-repo/TribeDispenser.git
cd TribeDispenser/packages/contracts
pnpm install
```

### 3. Deploy Contracts
Deploy the contracts using the provided deployment script after populating the `.env` file based of `.envsample`:
```bash
cd TribeDispenser/packages/contracts
pnpm deploy:pyrope
```

### 4. Interact with Contracts
Use the provided scripts or tools to interact with the deployed contracts. Refer to the `scripts/` folder for examples.

### 5. Testing
Run the test suite to verify the functionality:
```bash
cd TribeDispenser/packages/contracts
pnpm test
```

## System Details

The Tribe Recipe Dispenser system is designed with modularity and scalability in mind. Key features include:

1. **Decentralized Recipe Management**:  
   Recipes are stored and managed on-chain, ensuring transparency and immutability.

2. **Tribe-Based Access Control**:  
   Only registered tribes and their members can access specific recipes, providing a secure and exclusive system.

3. **Efficient Distribution Mechanism**:  
   The `TribeDispenserSystem.sol` contract ensures recipes are distributed efficiently, with mechanisms to prevent misuse or unauthorized access.

4. **Extensibility**:  
   The contracts are designed to be modular, allowing for easy addition of new features or integration with other systems.

## Contributing

Contributions are welcome! Please fork the repository, make your changes, and submit a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
