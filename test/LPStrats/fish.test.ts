import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    // {
    //     name: "FishUsdcUsx",
    //     controller: "fish",
    //     slot: 1
    // },
    // {
    //     name: "FishTusdUsdc",
    //     controller: "fish",
    //     slot: 1
    // },
    // {
    //     name: "FishAgEurUsdc",
    //     controller: "fish",
    //     slot: 1
    // },
    // {
    //     name: "FishWethWbtc",
    //     controller: "fish",
    //     slot: 1
    // },
    {
        name: "FishWstEthWeth",
        controller: "fish",
        slot: 1
    }

];

describe("SwapFish LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test
        };
        doStrategyTest(Test);
    }
});