# Security Tests

The contracts in this folder are the fuzz scripts for the Auto Surplus Auctioned Setter.

To run the fuzzer, set up Echidna (https://github.com/crytic/echidna).

Then run
```
echidna-test src/test/fuzz/<name of file>.sol --contract <Name of contract> --config src/test/fuzz/echidna.yaml
```

Configs are in this folder (echidna.yaml).

The contracts in this folder are modified versions of the originals in the _src_ folder. They have assertions added to test for invariants, visibility of functions modified. Running the Fuzz against modified versions without the assertions is still possible, general properties on the Fuzz contract can be executed against unmodified contracts.

For all contracts being fuzzed, we tested the following:

1. (FuzzBounds.sol) We test it against the mock version, forcing failures on overflows. This test should be run with a short ```seqLen``` and with ```checkAsserts: true``` in the config file. It will fail on overflows and give insights on bounds where calculations fail. Each failure should then be analyzed against expected running conditions.
2. (FuzzProperties.sol) We test invariants and properties on the contract, including correct surplus buffer calculation.

Echidna will generate random values and call all functions failing either for violated assertions, or for properties (functions starting with echidna_) that return false. Sequence of calls is limited by seqLen in the config file. Calls are also spaced over time (both block number and timestamp) in random ways. Once the fuzzer finds a new execution path, it will explore it by trying execution with values close to the ones that opened the new path.

# Results

### Fuzzing Bounds
```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-auto-surplus-auctioned/src/test/fuzz/AuctionedSurplusSetterFuzz.sol:FuzzBounds
assertion in rmultiply: failed!💥
  Call sequence:
    rmultiply(2697827525297810266870328011272606575,45700612467396440496866969060923131761892)

assertion in ray: failed!💥
  Call sequence:
    ray(115829337580713849821712494520990068503764512982426941730778489270260)

assertion in multiply: failed!💥
  Call sequence:
    multiply(19499480037117419217865465986356979824268647195666270301650512244145532399334,6)

assertion in baseUpdateCallerReward: passed! 🎉
assertion in maxRewardIncreaseDelay: passed! 🎉
assertion in authorizedAccounts: passed! 🎉
assertion in treasuryAllowance: passed! 🎉
assertion in addAuthorization: passed! 🎉
assertion in wmultiply: failed!💥
  Call sequence:
    wmultiply(2,57964607514682244116301744547113912951939219865160434533241870562907077037120)

assertion in subtract: failed!💥
  Call sequence:
    subtract(0,1)

assertion in targetValue: passed! 🎉
assertion in perSecondCallerRewardIncrease: passed! 🎉
assertion in rad: failed!💥
  Call sequence:
    rad(115854577237921995917790371579383720717253929704397)

assertion in oracleRelayer: passed! 🎉
assertion in addition: failed!💥
  Call sequence:
    addition(80060996589961191649985835278617287959987060981438809666923612368680521767252,35998051013888632081562042937723574662188154618061231804626440394500733349490)

assertion in RAY: passed! 🎉
assertion in updateDelay: passed! 🎉
assertion in treasury: passed! 🎉
assertion in modifyParameters: passed! 🎉
assertion in maxUpdateCallerReward: passed! 🎉
assertion in WAD: passed! 🎉
assertion in targetValueInflationUpdateTime: passed! 🎉
assertion in fuzz_params: passed! 🎉
assertion in removeAuthorization: passed! 🎉
assertion in accountingEngine: passed! 🎉
assertion in rdivide: failed!💥
  Call sequence:
    rdivide(115886164573148291020432382480065948745155961726782,2525959153237729307734718239684989008389347015779)

assertion in minAuctionedSurplus: passed! 🎉
assertion in recomputeSurplusAmountAuctioned: failed!💥
  Call sequence:
    fuzz_params(510705291612682415300464859605962355733710686227,116079233110776708235769058719260805481399908875828)
    recomputeSurplusAmountAuctioned(0x0)

assertion in targetValueTargetInflation: passed! 🎉
assertion in targetValueInflationDelay: passed! 🎉
assertion in lastUpdateTime: passed! 🎉
assertion in rpower: failed!💥
  Call sequence:
    rpower(2472,23,1)

assertion in minimum: passed! 🎉
assertion in getCallerReward: failed!💥
  Call sequence:
    getCallerReward(1,0)

assertion in wdivide: failed!💥
  Call sequence:
    wdivide(115792389786299390673194008857570350989155031672833084572450,9110416146516350831414530238548909262859433559447647428)

assertion in MAX_INFLATION: passed! 🎉
assertion in modifyParameters: passed! 🎉

Seed: -7665845288211698131
```

Several of the failures are expected, known limitations of safeMath, as follows:

- rmultiply
- ray
- multiply
- wmultiply
- subtract
- rad
- addition
- rdivide:
- rpower
- getCallerReward (previously tested on the ```increasingTreasuryReimbursement```)
- wdivide

The call to recomputeSurplusAmountAuctioned failed with these parameters:
fuzz_params(47916265891128888918622939068852463954986419576320732,115838038528814585204844706750205778109531377501224)

redemptionPrice: 47,916,265,891,128,888,918,622,939,068,852,463.954986419576320732
targetValue: 115,838,038,528,814,585,204,844.706750205778109531377501224

Bounds are plentiful, the system under normal conditions will never get close to these numbers.

### Conclusion: No exceptions found.

### Fuzz Execution

In this case we setup an environment and test for properties.

The redemptionPrice is fuzzed in between calls (haphazardly) so we have different scenarios where the surplus buffer is calculated.

Here we are not looking for bounds, but instead checking the properties that either should remain constant, or that move as the auction evolves:

- updateDelay
- reward parameters
- minAuctionSurplus
- surplus auctioned calculation
- surplus auctioned bounds
- parameter change on accounting engine

These properties are verified in between all calls.

```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-auto-surplus-auctioned/src/test/fuzz/AuctionedSurplusSetterFuzz.sol:FuzzProperties
echidna_per_second_reward_increase: passed! 🎉
echidna_surplus_auctined_bounds: passed! 🎉
echidna_min_auction_surplus: passed! 🎉
echidna_base_update_caller_reward: passed! 🎉
echidna_max_rewasrd_increase_delay: passed! 🎉
echidna_update_delay: passed! 🎉
echidna_recompute_surplus_auctioned: passed! 🎉
echidna_max_update_caller_reward: passed! 🎉

Seed: -348532734073948523

```

#### Conclusion: No exceptions found.

