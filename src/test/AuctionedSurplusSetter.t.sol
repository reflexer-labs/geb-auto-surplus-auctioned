pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./mock/MockTreasury.sol";
import "../AuctionedSurplusSetter.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract Feed {
    uint256 public priceFeedValue;
    bool public hasValidValue;
    constructor(uint256 initPrice, bool initHas) public {
        priceFeedValue = uint(initPrice);
        hasValidValue = initHas;
    }
    function set_val(uint newPrice) external {
        priceFeedValue = newPrice;
    }
    function set_has(bool newHas) external {
        hasValidValue = newHas;
    }
    function getResultWithValidity() external returns (uint256, bool) {
        return (priceFeedValue, hasValidValue);
    }
}
contract AccountingEngine {
    uint256 public surplusAuctionAmountToSell;

    function modifyParameters(bytes32 parameter, uint data) external {
        if (parameter == "surplusAuctionAmountToSell") surplusAuctionAmountToSell = data;
    }
}
contract OracleRelayer {
    uint256 public redemptionPrice = 3 ether;

    function modifyParameters(bytes32 parameter, uint data) external {
        if (parameter == "redemptionPrice") redemptionPrice = data;
    }
}

contract Caller {
    AuctionedSurplusSetter setter;

    constructor (AuctionedSurplusSetter add) public {
        setter = add;
    }

    function doModifyParameters(bytes32 param, uint256 data) public {
        setter.modifyParameters(param, data);
    }

    function doModifyParameters(bytes32 param, address data) public {
        setter.modifyParameters(param, data);
    }

    function doAddAuthorization(address data) public {
        setter.addAuthorization(data);
    }

    function doRemoveAuthorization(address data) public {
        setter.removeAuthorization(data);
    }

    function doRecomputeSurplusAmountAuctioned() public {
        setter.recomputeSurplusAmountAuctioned(address(0));
    }
}

contract AuctionedSurplusSetterTest is DSTest {
    Hevm hevm;

    DSToken systemCoin;

    Feed sysCoinFeed;

    AuctionedSurplusSetter setter;
    AccountingEngine accountingEngine;
    OracleRelayer oracleRelayer;
    MockTreasury treasury;
    Caller caller;

    uint256 constant RAY = 10 ** 27;
    uint256 constant WAD = 10 ** 18;

    uint256 targetValue = 3 * RAY;
    uint256 minAuctionedSurplus = 50 * WAD;
    uint256 updateDelay = 3600;
    uint256 baseUpdateCallerReward = 5E18;
    uint256 maxUpdateCallerReward  = 10E18;
    uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848; // 100% per hour
    uint256 maxRewardIncreaseDelay = 3 hours;

    uint256 coinsToMint = 1E40;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        systemCoin = new DSToken("RAI", "RAI");
        treasury = new MockTreasury(address(systemCoin));
        accountingEngine = new AccountingEngine();
        oracleRelayer = new OracleRelayer();

        sysCoinFeed = new Feed(2.015 ether, true);

        setter = new AuctionedSurplusSetter(
            address(treasury),
            address(oracleRelayer),
            address(accountingEngine),
            minAuctionedSurplus,
            targetValue,
            updateDelay,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease
        );

        systemCoin.mint(address(treasury), coinsToMint);

        treasury.setTotalAllowance(address(setter), uint(-1));
        treasury.setPerBlockAllowance(address(setter), 10E45);

        caller = new Caller(setter);
    }

    function test_setup() public {
        assertTrue(address(setter.treasury()) == address(treasury));
        assertTrue(address(setter.accountingEngine()) == address(accountingEngine));
        assertTrue(address(setter.oracleRelayer()) == address(oracleRelayer));
        assertEq(setter.authorizedAccounts(address(this)), 1);
        assertEq(setter.minAuctionedSurplus(), minAuctionedSurplus);
        assertEq(setter.targetValue(), targetValue);
        assertEq(setter.baseUpdateCallerReward(), baseUpdateCallerReward);
        assertEq(setter.maxUpdateCallerReward(), maxUpdateCallerReward);
        assertEq(setter.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease);
        assertEq(setter.updateDelay(), updateDelay);
        assertEq(setter.maxRewardIncreaseDelay(), uint(-1));
        assertEq(setter.targetValueInflationUpdateTime(), now);
        assertEq(setter.targetValueInflationDelay(), uint(-1) / 2);
        assertEq(setter.targetValueTargetInflation(), 0);
    }

    function testFail_setup_null_oracle_relayer() public {
        setter = new AuctionedSurplusSetter(
            address(treasury),
            address(0),
            address(accountingEngine),
            minAuctionedSurplus,
            targetValue,
            updateDelay,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease
        );
    }
    function testFail_setup_null_accounting_engine() public {
        setter = new AuctionedSurplusSetter(
            address(treasury),
            address(oracleRelayer),
            address(0),
            minAuctionedSurplus,
            targetValue,
            updateDelay,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease
        );
    }
    function testFail_setup_invalid_min_surplus() public {
        setter = new AuctionedSurplusSetter(
            address(treasury),
            address(oracleRelayer),
            address(accountingEngine),
            0,
            targetValue,
            updateDelay,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease
        );
    }
    function testFail_setup_invalid_target_value() public {
        setter = new AuctionedSurplusSetter(
            address(treasury),
            address(oracleRelayer),
            address(accountingEngine),
            minAuctionedSurplus,
            0,
            updateDelay,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease
        );
    }
    function testFail_setup_invalid_update_delay() public {
        setter = new AuctionedSurplusSetter(
            address(treasury),
            address(oracleRelayer),
            address(accountingEngine),
            minAuctionedSurplus,
            targetValue,
            0,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease
        );
    }

    function test_add_authorization() public {
        setter.addAuthorization(address(0xfab));
        assertEq(setter.authorizedAccounts(address(0xfab)), 1);
    }

    function test_remove_authorization() public {
        setter.removeAuthorization(address(this));
        assertEq(setter.authorizedAccounts(address(this)), 0);
    }

    function testFail_add_authorization_unauthorized() public {
        caller.doAddAuthorization(address(0xfab));
    }

    function testFail_remove_authorization_unauthorized() public {
        caller.doRemoveAuthorization(address(this));
    }

    function test_modify_parameters() public {
        setter.modifyParameters("minAuctionedSurplus", 500 * WAD);
        assertEq(setter.minAuctionedSurplus(), 500 * WAD);

        setter.modifyParameters("targetValue", 5 * RAY);
        assertEq(setter.targetValue(), 5 * RAY);

        setter.modifyParameters("baseUpdateCallerReward", 4);
        assertEq(setter.baseUpdateCallerReward(), 4);

        setter.modifyParameters("maxUpdateCallerReward", 5);
        assertEq(setter.maxUpdateCallerReward(), 5);

        setter.modifyParameters("perSecondCallerRewardIncrease", 1 * RAY);
        assertEq(setter.perSecondCallerRewardIncrease(), 1 * RAY);

        setter.modifyParameters("maxRewardIncreaseDelay", 1 hours);
        assertEq(setter.maxRewardIncreaseDelay(), 1 hours);

        setter.modifyParameters("updateDelay", 14 hours);
        assertEq(setter.updateDelay(), 14 hours);

        setter.modifyParameters("treasury", address(4));
        assertEq(address(setter.treasury()), address(4));

        hevm.warp(now + 5);

        setter.modifyParameters("targetValueInflationUpdateTime", now - 1);
        assertEq(setter.targetValueInflationUpdateTime(), now - 1);

        setter.modifyParameters("targetValueInflationDelay", uint(-1) / 2);
        assertEq(setter.targetValueInflationDelay(), uint(-1) / 2);

        setter.modifyParameters("targetValueTargetInflation", 7);
        assertEq(setter.targetValueTargetInflation(), 7);
    }

    function testFail_modify_parameters_null_address() public {
        setter.modifyParameters("treasury", address(0));
    }

    function testFail_modify_parameters_invalid_param_address() public {
        setter.modifyParameters("invalid", address(1));
    }

    function testFail_modify_parameters_invalid_param_uint() public {
        setter.modifyParameters("invalid", 1);
    }

    function testFail_modify_parameters_unauthorized_address() public {
        caller.doModifyParameters("rewardDripper", address(1));
    }

    function testFail_modify_parameters_unauthorized_uint() public {
        caller.doModifyParameters("systemCoinsToRequest", 5 ether);
    }

    function testFail_modify_parameters_null_min_auctioned_surplus() public {
        setter.modifyParameters("minAuctionedSurplus", 0);
    }

    function testFail_modify_parameters_null_target_value() public {
        setter.modifyParameters("targetValue", 0);
    }

    function testFail_modify_parameters_large_targetValueInflationUpdateTime() public {
        setter.modifyParameters("targetValueInflationUpdateTime", now + 1);
    }

    function testFail_modify_parameters_small_targetValueInflationUpdateTime() public {
        setter.modifyParameters("targetValueInflationUpdateTime", setter.targetValueInflationUpdateTime() - 1);
    }

    function testFail_modify_parameters_large_targetValueInflationDelay() public {
        setter.modifyParameters("targetValueInflationDelay", uint(-1) / 2 + 1);
    }

    function testFail_modify_parameters_large_targetValueTargetInflation() public {
        setter.modifyParameters("targetValueTargetInflation", setter.MAX_INFLATION() + 1);
    }

    function testFail_modify_parameters_invalid_max_update_caller_reward() public {
        setter.modifyParameters("maxUpdateCallerReward", baseUpdateCallerReward - 1);
    }

    function testFail_modify_parameters_invalid_base_update_caller_reward() public {
        setter.modifyParameters("baseUpdateCallerReward", maxUpdateCallerReward + 1);
    }

    function testFail_modify_parameters_invalid_per_second_reward_increase() public {
        setter.modifyParameters("perSecondCallerRewardIncrease", RAY - 1);
    }

    function testFail_modify_parameters_null_max_reward_increase_delay() public {
        setter.modifyParameters("maxRewardIncreaseDelay", 0);
    }

    function testFail_modify_parameters_null_update_delay() public {
        setter.modifyParameters("updateDelay", 0);
    }

    function test_recompute_surplus_amount_auctioned_self_reward() public {
        assertEq(accountingEngine.surplusAuctionAmountToSell(), 0);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(systemCoin.balanceOf(address(caller)), baseUpdateCallerReward);
        assertEq(setter.lastUpdateTime(), now);
        assertEq(accountingEngine.surplusAuctionAmountToSell(), ((targetValue * RAY) / oracleRelayer.redemptionPrice()) * WAD);
    }

    function test_recompute_surplus_amount_auctioned_other_reward() public {
        assertEq(accountingEngine.surplusAuctionAmountToSell(), 0);
        setter.recomputeSurplusAmountAuctioned(address(0xfab));
        assertEq(systemCoin.balanceOf(address(0xfab)), baseUpdateCallerReward);
        assertEq(setter.lastUpdateTime(), now);
        assertEq(accountingEngine.surplusAuctionAmountToSell(), ((targetValue * RAY) / oracleRelayer.redemptionPrice()) * WAD);
    }

    function testFail_recompute_surplus_amount_auctioned_same_block() public {
        assertEq(accountingEngine.surplusAuctionAmountToSell(), 0);
        setter.recomputeSurplusAmountAuctioned(address(0xfab));
        setter.recomputeSurplusAmountAuctioned(address(0xfab));
    }

    function testFail_recompute_surplus_amount_auctioned_before_delay() public {
        assertEq(accountingEngine.surplusAuctionAmountToSell(), 0);
        setter.recomputeSurplusAmountAuctioned(address(0xfab));
        hevm.warp(now + updateDelay - 1);
        setter.recomputeSurplusAmountAuctioned(address(0xfab));
    }

    function test_recompute_surplus_amount_auctioned_fuzz(uint redemptionPrice, uint targetValue_) public {
        redemptionPrice = redemptionPrice % 100000 ether + 1;
        targetValue_    = targetValue_ % 100000 * RAY + 100;

        setter.modifyParameters("targetValue", targetValue_);
        oracleRelayer.modifyParameters("redemptionPrice", redemptionPrice);

        caller.doRecomputeSurplusAmountAuctioned();

        assertEq(accountingEngine.surplusAuctionAmountToSell(), ((targetValue_ * RAY) / redemptionPrice) * WAD);
    }

    function test_recompute_once_with_inflation() public {
        setter.modifyParameters("targetValueInflationDelay", 1 days);
        setter.modifyParameters("targetValueTargetInflation", 10);

        uint currentTargetValue = setter.targetValue();

        hevm.warp(now + 1 hours);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(setter.targetValueInflationUpdateTime(), now - 1 hours);

        hevm.warp(now + 23 hours);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(setter.targetValueInflationUpdateTime(), now);

        assertEq(setter.targetValue(), currentTargetValue + currentTargetValue * 10 / 100);
    }

    function test_recompute_first_update_with_inflation_large_delay() public {
        setter.modifyParameters("targetValueInflationDelay", 1 days);
        setter.modifyParameters("targetValueTargetInflation", 10);

        uint currentTargetValue = setter.targetValue();

        hevm.warp(now + 10 days);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(setter.targetValueInflationUpdateTime(), now);
    }

    function test_multi_recompute_with_inflation() public {
        setter.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        setter.modifyParameters("targetValueInflationDelay", 1 days);
        setter.modifyParameters("targetValueTargetInflation", 10);

        uint currentTargetValue = setter.targetValue();

        hevm.warp(now + 1 hours);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(setter.targetValueInflationUpdateTime(), now - 1 hours);

        hevm.warp(now + 95 hours);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(setter.targetValueInflationUpdateTime(), now);

        for (uint i = 0; i < 4; i++) {
            currentTargetValue = currentTargetValue + currentTargetValue / 100 * 10;
        }

        assertEq(setter.targetValue(), currentTargetValue);
    }

    function testFail_multi_recompute_large_delay() public {
        setter.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        setter.modifyParameters("targetValueInflationDelay", 1 days);
        setter.modifyParameters("targetValueTargetInflation", 10);

        uint currentTargetValue = setter.targetValue();

        hevm.warp(now + 1 hours);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(setter.targetValueInflationUpdateTime(), now - 1 hours);

        hevm.warp(now + 3650 days);
        caller.doRecomputeSurplusAmountAuctioned();
        assertEq(setter.targetValueInflationUpdateTime(), now);
    }
}
