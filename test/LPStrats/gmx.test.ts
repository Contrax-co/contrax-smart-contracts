import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "Gmx",
        controller: "gmx",
        slot: 5
    },

];

describe("GMX LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test,
        
        };
        doStrategyTest(Test);
    }
});