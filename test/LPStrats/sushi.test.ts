import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    // {
    //     name: "SushiWethDai",
    //     vaultAddress: "0x99019bb5a75de37Ca8581BAdDE617d83e8D5B4b6"
    // },
    {
        name: "SushiWethUsdc"
    }

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