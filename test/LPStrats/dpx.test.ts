import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "DpxWethDpx",
        controller: "sushi"
    },

];

describe("DPX LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test,
            slot: 1
        };
        doStrategyTest(Test);
    }
});