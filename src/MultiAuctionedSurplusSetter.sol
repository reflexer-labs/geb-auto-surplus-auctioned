pragma solidity ^0.6.7;

import "geb-treasury-reimbursement/reimbursement/multi/MultiIncreasingTreasuryReimbursement.sol";

abstract contract AccountingEngineLike {
    function modifyParameters(bytes32, bytes32, uint256) virtual external;
}
abstract contract OracleRelayerLike {
    function redemptionPrice(bytes32) virtual external returns (uint256);
}

contract MultiAuctionedSurplusSetter is MultiIncreasingTreasuryReimbursement {
    // --- Variables ---
    // Minimum amount of surplus to sell in one auction
    uint256 public minAuctionedSurplus;                                  // [rad]
    // Target value for the amount of surplus to sell
    uint256 public targetValue;                                          // [ray]
    // The min delay between two adjustments of the surplus amount
    uint256 public updateDelay;                                          // [seconds]
    // Last timestamp when the surplus amount was updated
    uint256 public lastUpdateTime;                                       // [unix timestamp]
    // Delay between two consecutive inflation related updates
    uint256 public targetValueInflationDelay;
    // The target inflation applied to targetValue
    uint256 public targetValueTargetInflation;
    // The last time when inflation was applied to the target value
    uint256 public targetValueInflationUpdateTime;                       // [unix timestamp]

    // Accounting engine contract
    AccountingEngineLike public accountingEngine;
    // The oracle relayer contract
    OracleRelayerLike    public oracleRelayer;

    // Max inflation per period
    uint256 public constant MAX_INFLATION = 50;

    // --- Events ---
    event RecomputeSurplusAmountAuctioned(uint256 surplusToSell);

    constructor(
      bytes32 coinName_,
      address treasury_,
      address oracleRelayer_,
      address accountingEngine_,
      uint256 minAuctionedSurplus_,
      uint256 targetValue_,
      uint256 updateDelay_,
      uint256 baseUpdateCallerReward_,
      uint256 maxUpdateCallerReward_,
      uint256 perSecondCallerRewardIncrease_
    ) public MultiIncreasingTreasuryReimbursement(coinName_, treasury_, baseUpdateCallerReward_, maxUpdateCallerReward_, perSecondCallerRewardIncrease_) {
        require(both(oracleRelayer_ != address(0), accountingEngine_ != address(0)), "MultiAuctionedSurplusSetter/invalid-core-contracts");
        require(minAuctionedSurplus_ > 0, "MultiAuctionedSurplusSetter/invalid-min-auctioned-surplus");
        require(targetValue_ > 0, "MultiAuctionedSurplusSetter/invalid-target-value");
        require(updateDelay_ > 0, "MultiAuctionedSurplusSetter/null-update-delay");

        minAuctionedSurplus            = minAuctionedSurplus_;
        updateDelay                    = updateDelay_;
        targetValue                    = targetValue_;
        targetValueTargetInflation     = 0;
        targetValueInflationDelay      = uint(-1) / 2;
        targetValueInflationUpdateTime = now;

        oracleRelayer                  = OracleRelayerLike(oracleRelayer_);
        accountingEngine               = AccountingEngineLike(accountingEngine_);

        emit ModifyParameters("minAuctionedSurplus", minAuctionedSurplus);
        emit ModifyParameters("targetValue", targetValue);
        emit ModifyParameters("updateDelay", updateDelay);
    }

    // --- Boolean Logic ---
    function both(bool x, bool y) internal pure returns (bool z) {
      assembly{ z := and(x, y)}
    }

    // --- Math ---
    uint internal constant HUNDRED  = 100;

    // --- Administration ---
    /*
    * @notify Modify an uint256 parameter
    * @param parameter The name of the parameter to change
    * @param val The new parameter value
    */
    function modifyParameters(bytes32 parameter, uint256 val) external isAuthorized {
        if (parameter == "minAuctionedSurplus") {
          require(val > 0, "MultiAuctionedSurplusSetter/null-min-auctioned-amount");
          minAuctionedSurplus = val;
        }
        else if (parameter == "targetValue") {
          require(val >= 100, "MultiAuctionedSurplusSetter/null-target-value");
          targetValue = val;
        }
        else if (parameter == "baseUpdateCallerReward") {
          require(val <= maxUpdateCallerReward, "MultiAuctionedSurplusSetter/invalid-min-reward");
          baseUpdateCallerReward = val;
        }
        else if (parameter == "maxUpdateCallerReward") {
          require(val >= baseUpdateCallerReward, "MultiAuctionedSurplusSetter/invalid-max-reward");
          maxUpdateCallerReward = val;
        }
        else if (parameter == "perSecondCallerRewardIncrease") {
          require(val >= RAY, "MultiAuctionedSurplusSetter/invalid-reward-increase");
          perSecondCallerRewardIncrease = val;
        }
        else if (parameter == "maxRewardIncreaseDelay") {
          require(val > 0, "MultiAuctionedSurplusSetter/invalid-max-increase-delay");
          maxRewardIncreaseDelay = val;
        }
        else if (parameter == "updateDelay") {
          require(val > 0, "MultiAuctionedSurplusSetter/null-update-delay");
          updateDelay = val;
        }
        else if (parameter == "targetValueInflationUpdateTime") {
          require(both(val >= targetValueInflationUpdateTime, val <= now), "MultiAuctionedSurplusSetter/invalid-inflation-update-time");
          targetValueInflationUpdateTime = val;
        }
        else if (parameter == "targetValueInflationDelay") {
          require(val <= uint(-1) / 2, "MultiAuctionedSurplusSetter/invalid-inflation-delay");
          targetValueInflationDelay = val;
        }
        else if (parameter == "targetValueTargetInflation") {
          require(val <= MAX_INFLATION, "MultiAuctionedSurplusSetter/invalid-target-inflation");
          targetValueTargetInflation = val;
        }
        else revert("MultiAuctionedSurplusSetter/modify-unrecognized-param");
        emit ModifyParameters(parameter, val);
    }
    /*
    * @notify Modify an address param
    * @param parameter The name of the parameter to change
    * @param addr The new address for the parameter
    */
    function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
        require(addr != address(0), "MultiAuctionedSurplusSetter/null-address");
        if (parameter == "treasury") treasury = StabilityFeeTreasuryLike(addr);
        else revert("MultiAuctionedSurplusSetter/modify-unrecognized-param");
        emit ModifyParameters(parameter, addr);
    }

    // --- Core Logic ---
    /*
    * @notify Recompute and set the new amount of surplus that's sold in one surplus auction
    */
    function recomputeSurplusAmountAuctioned(address feeReceiver) public {
        // Check delay between calls
        require(either(subtract(now, lastUpdateTime) >= updateDelay, lastUpdateTime == 0), "MultiAuctionedSurplusSetter/wait-more");
        // Get the caller's reward
        uint256 callerReward = getCallerReward(lastUpdateTime, updateDelay);
        // Store the timestamp of the update
        lastUpdateTime = now;

        // Apply inflation
        applyInflation();

        // Calculate the new amount to sell
        uint256 surplusToSell = multiply(rdivide(targetValue, oracleRelayer.redemptionPrice(coinName)), WAD);
        surplusToSell         = (surplusToSell < minAuctionedSurplus) ? minAuctionedSurplus : surplusToSell;

        // Set the new amount
        accountingEngine.modifyParameters(coinName, "surplusAuctionAmountToSell", surplusToSell);

        // Emit an event
        emit RecomputeSurplusAmountAuctioned(surplusToSell);

        // Pay the caller for updating the rate
        rewardCaller(feeReceiver, callerReward);
    }

    // --- Internal Logic ---
    /*
    * @notice Automatically apply inflation to the targetValue
    */
    function applyInflation() internal {
        uint256 updateSlots = subtract(now, targetValueInflationUpdateTime) / targetValueInflationDelay;
        if (updateSlots == 0) return;

        targetValueInflationUpdateTime = addition(targetValueInflationUpdateTime, multiply(updateSlots, targetValueInflationDelay));
        targetValue = multiply(targetValue, rpower((HUNDRED + targetValueTargetInflation), updateSlots, 1)) / rpower(HUNDRED, updateSlots, 1);
    }
}
