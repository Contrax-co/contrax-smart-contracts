import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "DodoUsdtLp",
        controller: "dodo",
        slot: 5,
    },
    {
      name: "DodoUsdcLp",
      controller: "dodo",
      slot: 5,
    },
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