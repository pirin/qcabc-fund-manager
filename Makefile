-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil deployFundManager deployShareToken deployMockUsdc generate-abis

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install forge install foundry-rs/forge-std --no-commit && forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1


#make ARGS="--network sepolia" deploy;     
NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(BASE_SEPOLIA_RPC_URL) --account $(BASE_SEPOLIA_OWNER_WALLET_NAME) --broadcast --verify --etherscan-api-key $(BASESCAN_API_KEY) -vvvvv
endif

deploy: deployFundManager generate-abis

deployFundManager:
	@echo "Deploying FundManager..."
	@forge script script/DeployFundManager.s.sol:DeployFundManager $(NETWORK_ARGS)

deployShareToken:
	@echo "Deploying ShareToken Manager..."
	@forge script script/DeployMockUSDC.s.sol:DeployMockUSDC $(NETWORK_ARGS)

deployMockUsdc:
	@echo Deploying MockUSDC...
	@forge script script/DeployMockUSDC.s.sol:DeployMockUSDC $(NETWORK_ARGS)

#===============================================================================
generate-abis:
	node scripts-js/generateTsAbis.js $(NEXTJS_TARGET_DIR)