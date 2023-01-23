import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "CamelotGmxUsdc",
        controller: "sushi",
        slot: 1
    },

];

describe("Camelot LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test
        };
        doStrategyTest(Test);
    }
});