import { OPERATOR_SAFE } from "../../addresses";

// The 4-of-7 committee multisig is the only member. Individual signers are
// managed inside that Safe, so rotating a signer never touches this role.
export default [OPERATOR_SAFE] satisfies Members;
