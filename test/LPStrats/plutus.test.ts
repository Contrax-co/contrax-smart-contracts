import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    // {
    //     name: "PlutusPlsDpx",
    //     controller: "plutus",
    //     slot: 0
    // },
    {
        name: "PlutusPlsWeth",
        controller: "plutus",
        slot: 1,
    }, 
    // {
    //     name: "PlutusDpxPlsDpx",
    //     controller: "plutus",
    //     slot: 1,
    // }

];

describe("Plutus test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test
        };
        doStrategyTest(Test);
    }
});