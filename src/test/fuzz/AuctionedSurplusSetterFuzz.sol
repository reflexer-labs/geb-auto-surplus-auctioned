pragma solidity ^0.6.7;

import "./AuctionedSurplusSetterMock.sol";
import "./MockTreasury.sol";

contract AccountingEngineMock {
    uint256 public surplusAuctionAmountToSell;

    function modifyParameters(bytes32 parameter, uint data) external {
        if (parameter == "surplusAuctionAmountToSell") surplusAuctionAmountToSell = data;
    }
}
contract OracleRelayerMock {
    uint256 public redemptionPrice = 3 ether;

    function modifyParameters(bytes32 parameter, uint data) external {
        if (parameter == "redemptionPrice") redemptionPrice = data;
    }
}

contract TokenMock {
    uint constant maxUint = uint(0) - 1;
    mapping (address => uint256) public received;
    mapping (address => uint256) public sent;

    function totalSupply() public view returns (uint) {
        return maxUint;
    }
    function balanceOf(address src) public view returns (uint) {
        return maxUint;
    }
    function allowance(address src, address guy) public view returns (uint) {
        return maxUint;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        received[dst] += wad;
        sent[src]     += wad;
        return true;
    }

    function approve(address guy, uint wad) virtual public returns (bool) {
        return true;
    }
}

// @notice Fuzz the whole thing, assess the results to see if failures make sense
contract FuzzBounds is AuctionedSurplusSetterMock {
    constructor() public
        AuctionedSurplusSetterMock(
            address(new MockTreasury(address(new TokenMock()))),
            address(new OracleRelayerMock()),
            address(new AccountingEngineMock()),
            50 * WAD,                    // minAuctionedSurplus
            3 * RAY,                     // targetValue
            3600,                        // updateDelay
            5E18,                        // baseUpdateCallerReward
            10E18,                       // maxUpdateCallerReward
            1000192559420674483977255848 // perSecondCallerRewardIncrease
        ){
            authorizedAccounts[address(this)] = 1;
        }

    // aux
    function fuzz_params(uint redemptionPrice, uint targetValue_) public {
        this.modifyParameters("targetValue", targetValue_);
        OracleRelayerMock(address(oracleRelayer)).modifyParameters("redemptionPrice", redemptionPrice);
    }
}

// @notice Will fuzz the contract and check for invariants/properties
contract FuzzProperties is AuctionedSurplusSetterMock {

    constructor() public
        AuctionedSurplusSetterMock(
            address(new MockTreasury(address(new TokenMock()))),
            address(new OracleRelayerMock()),
            address(new AccountingEngineMock()),
            50 * WAD,                    // minAuctionedSurplus
            3 * RAY,                     // targetValue
            3600,                        // updateDelay
            5E18,                        // baseUpdateCallerReward
            10E18,                       // maxUpdateCallerReward
            1000192559420674483977255848 // perSecondCallerRewardIncrease
        ){
            authorizedAccounts[address(this)] = 1;
        }

    // aux
    function fuzz_params(uint redemptionPrice, uint targetValue_) public {
        this.modifyParameters("targetValue", targetValue_);
        OracleRelayerMock(address(oracleRelayer)).modifyParameters("redemptionPrice", redemptionPrice);
        recomputeSurplusAmountAuctioned(address(0));
    }

    // properties
    function echidna_min_auction_surplus() public returns (bool) {
        return minAuctionedSurplus == 50 * WAD;
    }

    function echidna_base_update_caller_reward() public returns (bool) {
        return baseUpdateCallerReward == 5E18;
    }

    function echidna_max_update_caller_reward() public returns (bool) {
        return maxUpdateCallerReward == 10E18;
    }

    function echidna_per_second_reward_increase() public returns (bool) {
        return perSecondCallerRewardIncrease == 1000192559420674483977255848;
    }

    function echidna_max_rewasrd_increase_delay() public returns (bool) {
        return minAuctionedSurplus == 50 * WAD;
    }

    function echidna_update_delay() public returns (bool) {
        return updateDelay == 3600;
    }

    function echidna_recompute_surplus_auctioned() public returns (bool) {
        if (lastUpdateTime == 0) return true; // not yet updated
        uint auctionedSurplus = ((targetValue * RAY) / oracleRelayer.redemptionPrice()) * WAD;
        auctionedSurplus = auctionedSurplus < minAuctionedSurplus ? minAuctionedSurplus : auctionedSurplus;
        return AccountingEngineMock(address(accountingEngine)).surplusAuctionAmountToSell() == auctionedSurplus;
    }

    function echidna_surplus_auctined_bounds() public returns (bool) {
        if (lastUpdateTime == 0) return true; // not yet updated
        return AccountingEngineMock(address(accountingEngine)).surplusAuctionAmountToSell() >= minAuctionedSurplus;
    }
}