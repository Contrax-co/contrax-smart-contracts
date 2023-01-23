import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "DodoUsdt",
        controller: "dodo",
        slot: 51
    },
    // {
    //   name: "DodoUsdc",
    //   controller: "dodo",
    //   slot: 51
    // },
];

describe("Dodo LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test
        };
        doStrategyTest(Test);
    }
});