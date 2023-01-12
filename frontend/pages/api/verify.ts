// Next.js API route support: https://nextjs.org/docs/api-routes/introduction
import type { NextApiRequest, NextApiResponse } from "next";
import { APIError } from "../../utilities/errors";

import vkey from "../../utilities/jsonFull_vkey.json";
import { VerifyPayload } from "../../utilities/types";

const snarkjs = require("snarkjs");

export async function verifyProof(publicSignals: any, proof: any): Promise<boolean> {
    const proofVerified = await snarkjs.groth16.verify(vkey, publicSignals, proof);

    return proofVerified;
}

export default async function handler(req: NextApiRequest, res: NextApiResponse<VerifyPayload | APIError>) {
    try {
        let body = req.body;
        if (typeof req.body === "string") {
            body = JSON.parse(body);
        }

        const { proof, publicSignals } = body;
        const isValidProof = await verifyProof(publicSignals, proof);

        res.status(200).json({ isValidProof });
    } catch (ex: unknown) {
        console.error(ex);
        res.status(404).json({ errMsg: "Unexpected error occurred verifying proof" });
    }
}
