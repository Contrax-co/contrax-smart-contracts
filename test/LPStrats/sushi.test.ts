import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
    // {
    //     name: "SushiWethDai",
    //     controller: "plutus",
    //     vaultAddress: "0xF73e52e7185dDE30eC58336bc186f392354bF784"
    // },
    // {
    //     name: "SushiWethUsdc",
    //     controller: "sushi",
    //     vaultAddress: "0x8C55e9D918B2315Eb3192C2bAFf07C2e9cf55E01"
    // },
    // {
    //     name: "SushiWethUsdt",
    //     controller: "sushi",
    //     vaultAddress: "0xa7bff08cADebFc239Aa6A127064Af4a05EA61Fcb"
    // },
    // {
    //     name: "SushiWethWbtc",
    //     controller: "sushi",
    //     vaultAddress: "0x3043e7675c956EAfcDF006458b296F1fe8B0CA7C"
    // },
    // {
    //     name: "SushiWethMagic",
    //     controller: "sushi"
    // },
    {
        name: "SushiAxlUsdcUsdc",
        controller: "sushi",
        slot: 3
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