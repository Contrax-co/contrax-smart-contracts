import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    {
        name: "SushiWethDai",
        controller: "sushi"
    },
    // {
    //     name: "SushiWethUsdc",
    //     controller: "sushi"
    // },
    // {
    //     name: "SushiWethUsdt",
    //     controller: "sushi"
    // },
    // {
    //     name: "SushiWethWbtc",
    //     controller: "sushi"
    // },
    // {
    //     name: "SushiWethMagic",
    //     controller: "sushi"
    // },

];

describe("Sushi LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test,
            slot: 1
        };
        doStrategyTest(Test);
    }
});