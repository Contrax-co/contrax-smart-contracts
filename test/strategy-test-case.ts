export interface TestableStrategy {
    type: string;
    name: string;
    controller: string;
    vaultAddress: string;
    strategyAddress: string;
    slot: number;
    fold: boolean;
    timelockIsStrategist: boolean;
}

export const FoldTestDefault: TestableStrategy = {
    type: "FOLD",
    name: "",
    controller: "main",
    vaultAddress: "",
    strategyAddress: "",
    slot: 0,
    fold: true,
    timelockIsStrategist: false,
}
export const SingleStakeTestDefault: TestableStrategy = {
    type: "SS",
    name: "",
    controller: "main",
    vaultAddress: "",
    strategyAddress: "",
    slot: 0,
    fold: false,
    timelockIsStrategist: true,
}
export const LPTestDefault: TestableStrategy = {
    type: "LP",
    name: "",
    controller: "main",
    vaultAddress: "",
    strategyAddress: "",
    slot: 0,
    fold: false,
    timelockIsStrategist: false,
}