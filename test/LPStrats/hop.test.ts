import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    // {
    //     name: "HopWeth",
    //     controller: "hop",
    // },
    // {
    //     name: "HopUsdc",
    //     controller: "hop",
    // },
    // {
    //     name: "HopUsdt",
    //     controller: "hop",
    // },
    {
        name: "HopDai",
        controller: "hop",
    },

];

describe("Hop LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test,
            slot: 0
        };
        doStrategyTest(Test);
    }
});