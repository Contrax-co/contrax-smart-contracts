import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "HopWeth",
        controller: "sushi",
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