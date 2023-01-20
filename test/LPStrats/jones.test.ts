import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "JonesWethJones",
        controller: "plutus",
        slot: 1,
    }

];

describe("Jones test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test
        };
        doStrategyTest(Test);
    }
});