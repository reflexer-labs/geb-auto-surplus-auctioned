# Security Tests

The contracts in this folder are the fuzz scripts for the the Auto Surplus Buffer.

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
    rmultiply(93,1260191625288971054583582550793823207616563315106944400055419087583553930494)

assertion in ray: failed!💥
  Call sequence:
    ray(116036357992552405406917100029970817036208202048814769444091386112617)

assertion in multiply: failed!💥
  Call sequence:
    multiply(12,9678091936453495786745380407792224045109658548729933571148274115121200122186)

assertion in baseUpdateCallerReward: passed! 🎉
assertion in maxRewardIncreaseDelay: passed! 🎉
assertion in authorizedAccounts: passed! 🎉
assertion in treasuryAllowance: passed! 🎉
assertion in addAuthorization: passed! 🎉
assertion in wmultiply: failed!💥
  Call sequence:
    wmultiply(24156526678279129388503861487529824221765190,5022258726974186609890421463183091)

assertion in subtract: failed!💥
  Call sequence:
    subtract(0,1)

assertion in targetValue: passed! 🎉
assertion in perSecondCallerRewardIncrease: passed! 🎉
assertion in rad: failed!💥
  Call sequence:
    rad(115808278160240558712791327816664322604904273914939)

assertion in oracleRelayer: passed! 🎉
assertion in addition: failed!💥
  Call sequence:
    addition(58969429071541794793211973775905358902446719080344407528938259675416725589085,57395340703033505185346658225753633631603291543301689264639989707893162057689)

assertion in RAY: passed! 🎉
assertion in updateDelay: passed! 🎉
assertion in treasury: passed! 🎉
assertion in modifyParameters: passed! 🎉
assertion in maxUpdateCallerReward: passed! 🎉
assertion in WAD: passed! 🎉
assertion in fuzz_params: passed! 🎉
assertion in removeAuthorization: passed! 🎉
assertion in accountingEngine: passed! 🎉
assertion in rdivide: failed!💥
  Call sequence:
    rdivide(116269754811533524570863564454148614729056037544213,1480901466999921940140397288772096495194582582883734)

assertion in minAuctionedSurplus: passed! 🎉
assertion in recomputeSurplusAmountAuctioned: failed!💥
  Call sequence:
    fuzz_params(47916265891128888918622939068852463954986419576320732,115838038528814585204844706750205778109531377501224)
    recomputeSurplusAmountAuctioned(0x0)

assertion in lastUpdateTime: passed! 🎉
assertion in rpower: failed!💥
  Call sequence:
    rpower(345372229699855413651133070345916285812,2,0)

assertion in minimum: passed! 🎉
assertion in getCallerReward: failed!💥
  Call sequence:
    getCallerReward(1,0)

assertion in wdivide: failed!💥
  Call sequence:
    wdivide(115936143111092068267914722197635915479219830969095213116047,485580644958702470870639439708765914251115767926492448482)

assertion in modifyParameters: passed! 🎉

Seed: -2303065758025009807
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

None other calls failed.


### Conclusion: No exceptions found.

### Fuzz Execution

In this case we setup an environment and test for properties.

The globalDebt in SAFEEngine is fuzzed in between calls (haphazardly) so we have different scenarios where the surplus buffer is calculated.

Here we are not looking for bounds, but instead checking the properties that either should remain constant, or that move as the auction evolves:

- stopAdjustments
- updateDelay
- minimumBufferSize
- maximumBufferSize
- minimumGlobalDebtChange
- coveredDebt
- surplus buffer calculation
- surplus buffer setting in AccountingEngine

These properties are verified in between all calls.

```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-auto-surplus-buffer/src/test/fuzz/AutoSurplusBufferSetterFuzz.sol:FuzzProperties
echidna_surplusBufferAdjustment: passed! 🎉
echidna_minimumGlobalDebtChange: passed! 🎉
echidna_stopAdjustments: passed! 🎉
echidna_maximumBufferSize: passed! 🎉
echidna_minimumBufferSize: passed! 🎉
echidna_updateDelay: passed! 🎉
echidna_coveredDebt: passed! 🎉
```

#### Conclusion: No exceptions found.

