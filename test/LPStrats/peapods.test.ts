import { doStrategyTest } from "../strategy-test.test";
import { TestableStrategy, LPTestDefault } from "../strategy-test-case";

const tests = [
  // {
  //   name: "PeapodsGmx",
  //   controller: "peapods",
  //   slot: 5
  // },
  // {
  //   name: "PeapodsOhm",
  //   controller: "peapods",
  // },
  // {
  //   name: "PeapodsPeas",
  //   controller: "peapods",
  // },
  {
    name: "PeapodsGmxOhm",
    controller: "sushi",
    slot: 1
  },
  // {
  //   name: "PeapodsSavvyOhm",
  //   controller: "peapods",
  // },
  // {
  //   name: "PeapodsPeasOhm",
  //   controller: "peapods",
  // },

];

describe("Peapods LP test", function() {
    for (const test of tests) {
        let Test: TestableStrategy = {
            ...LPTestDefault,
            ...test,
        
        };
        doStrategyTest(Test);
    }
});