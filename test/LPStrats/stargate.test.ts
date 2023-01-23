import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    // {
    //     name: "StargateUsdc",
    //     controller: "stargate",
    //     slot: 5
    // },
    // {
    //     name: "StargateUsdt",
    //     controller: "stargate",
    //     slot: 5
    // },
    {
        name: "StargateFrax",
        controller: "stargate",
        slot: 5
    },
    // {
    //     name: "StargateWeth",
    //     controller: "stargate",
    //     slot: 5
    // },
];

describe("Stargate LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test
        };
        doStrategyTest(Test);
    }
});