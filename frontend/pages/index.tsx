import Head from "next/head";
import styles from "../styles/Home.module.css";
import { Textarea } from "../components/textarea";
import React, { useEffect, useState } from "react";
import { Button } from "../components/button";
import localforage from "localforage";
import * as ed from "@noble/ed25519";
import * as ethers from "ethers";
import { JsonViewer } from "@textea/json-viewer";

import toast, { Toaster } from "react-hot-toast";
import {
    createJson,
    Ascii,
    isJSON,
    isJSONStore,
    JSONStringifyCustom,
    JSON_EL,
    JSON_STORE,
    MAX_JSON_LENGTH,
    padJSONString,
    preprocessJson,
    ProofArtifacts,
    toAscii,
} from "../utilities/json";
import styled from "styled-components";
import axios from "axios";
import { EddsaSignature, VerifyPayload } from "../utilities/types";
import { calculatePoseidon, generateEddsaSignature, hardCodedInput, strHashToBuffer } from "../utilities/crypto";
import { Card } from "../components/card";
import Link from "next/link";

const Container = styled.main`
    .viewProof {
        text-decoration: underline !important;
    }

    .underlineContainer {
        text-decoration: underline !important;
    }
`;

export default function Home() {
    const [jsonText, setJsonText] = useState<string>("");
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [hasKeypair, setHasKeypair] = useState<boolean>(false);
    const [signature, setSignature] = useState<EddsaSignature | undefined>(undefined);
    const [hash, setHash] = useState<string | undefined>(undefined);
    const [proofArtifacts, setProofArtifacts] = useState<ProofArtifacts | undefined>(undefined);
    const [formattedJSON, setFormattedJSON] = useState<string | undefined>(undefined);
    const [JsonDataStore, setJsonDataStore] = useState<JSON_STORE>({});

    const setRecursiveKeyInDataStore = (keys: string[], state: boolean) => {
        let newJson = { ...JsonDataStore };
        let ptr: JSON_EL | JSON_STORE = newJson;
        //TODO: handle nesting
        for (var key of keys) {
            if (isJSONStore(ptr) && typeof key === "string" && ptr[key] && ptr[key]) {
                ptr = ptr[key];
            } else {
                // ERROR
            }
        }
        if (!isJSONStore(ptr)) {
            ptr["ticked"] = state;
        }
        setJsonDataStore(newJson);
    };

    type FullJsonCircuitInput = {
        jsonProgram: Ascii[];
        keys: Ascii[][][];
        values: Ascii[][];
        keysOffset: number[][][];
        valuesOffset: number[][];
        hashJsonProgram: string;
        pubKey: string[];
        R8: string[];
        S: string[];
    };

    const generateProof = async () => {
        try {
            if (!isJSON(jsonText)) {
                toast.error("Invalid JSON");
                return;
            }
            setIsLoading(true);
            // hardCoded.jsonProgram.map(BigInt);

            if (jsonText) {
                console.log(formattedJSON);
                const obj = preprocessJson(JSON.parse(jsonText), 150);
                console.log(JSON.stringify(obj));

                const worker = new Worker("./worker.js");
                if (
                    obj &&
                    typeof hash == "string" &&
                    signature !== undefined &&
                    "pubKey" in signature &&
                    "R8" in signature &&
                    "S" in signature &&
                    Array.isArray(signature["pubKey"]) &&
                    Array.isArray(signature["R8"]) &&
                    Array.isArray(signature["S"])
                ) {
                    let objFull: FullJsonCircuitInput = {
                        ...obj,
                        hashJsonProgram: hash,
                        pubKey: signature["pubKey"],
                        R8: signature["R8"],
                        S: signature["S"],
                    };
                    worker.postMessage([hardCodedInput, "./jsonFull_final.zkey"]);
                } else {
                    setIsLoading(false);
                    toast.error(
                        "Invalid proving request. Please ensure that your JSON includes the required attributes"
                    );
                    return;
                }

                worker.onmessage = async function (e) {
                    const { proof, publicSignals } = e.data;
                    setProofArtifacts({ proof, publicSignals });

                    console.log("PROOF SUCCESSFULLY GENERATED: ", proof, publicSignals);
                    toast.success("Generated proof!");
                    setIsLoading(false);
                };
            }
        } catch (ex) {
            console.error(ex);
            toast.error("Something went wrong :(");
        }
    };

    console.log(ed.utils.bytesToHex(ed.utils.randomPrivateKey()));
    useEffect(() => {
        async function checkIsRegistered() {
            const maybePrivKey = await localforage.getItem("zkattestorPrivKey");
            const maybePubKey = await localforage.getItem("zkattestorPubKey");
            if (maybePrivKey && maybePubKey) {
                setHasKeypair(true);
            } else {
                setIsLoading(true);
                const privKey = ed.utils.randomPrivateKey();
                const publicKey = await ed.getPublicKey(privKey);
                await localforage.setItem("zkattestorPrivKey", privKey);
                await localforage.setItem("zkattestorPubKey", publicKey);
                setIsLoading(false);
            }
        }
        checkIsRegistered();
    }, []);

    const signJSON = async () => {
        if (!isJSON(jsonText)) {
            toast.error("Invalid JSON!");
            return;
        }
        const privateKey = await localforage.getItem("zkattestorPrivKey");
        const newFormattedJSON = padJSONString(JSON.stringify(JSON.parse(jsonText)), MAX_JSON_LENGTH);
        setFormattedJSON(newFormattedJSON);

        // Populate JSON_STORE with data from JSON.parse(jsonText);
        let newJsonDataStore: JSON_STORE = {};
        let parsedJson = JSON.parse(jsonText);

        createJson(parsedJson, newJsonDataStore);
        setJsonDataStore(newJsonDataStore);
        console.log("formatted: ", newFormattedJSON.length, jsonText.length);

        let hash = await calculatePoseidon(toAscii(newFormattedJSON));

        // const signature = await ed.sign(ethers.utils.toUtf8Bytes(newFormattedJSON), privateKey as string);
        const signature = await generateEddsaSignature(
            privateKey as Uint8Array,
            // ethers.utils.toUtf8Bytes(newFormattedJSON)
            strHashToBuffer(hash)
        );

        setHash(hash);
        setSignature(signature);
    };

    const verifyProof = async () => {
        try {
            const resultVerified = await axios.post<VerifyPayload>("/api/verify", { ...proofArtifacts });
            if (resultVerified.data.isValidProof) {
                toast.success("Successfully verified proof!");
            } else {
                toast.error("Failed to verify proof");
            }
        } catch (ex) {
            toast.error("Failed to verify proof");
        }
    };

    return (
        <>
            <Head>
                <title>Create Next App</title>
                <meta name="description" content="Generated by create next app" />
                <meta name="viewport" content="width=device-width, initial-scale=1" />
                <link rel="icon" href="/favicon.ico" />
            </Head>
            <Container className={styles.main}>
                <div className={`${styles.coolBackground} w-full flex justify-center items-center py-2 strong`}>
                    <div className="w-full flex justify-end items-center">
                        <div style={{ flex: "0.53" }}></div>
                        <h1 style={{ flex: "0.47" }} className="text-xl">
                            zkJSON
                        </h1>
                        <Link href="/partners">Trusted partners</Link>
                    </div>
                </div>

                <p className="mb-2">Select JSON elements to reveal in ZK-proof</p>
                <div className="py-2"></div>
                <div style={{ width: "800px" }} className="flex flex-col justify-center items-center">
                    {!hasKeypair ? (
                        "generating your key pair..."
                    ) : (
                        <div className="w-full flex flex-col items-center justify-center">
                            <Textarea
                                placeholder={"Paste your JSON string"}
                                value={jsonText}
                                onChangeHandler={(newVal: string) => {
                                    setJsonText(newVal);
                                }}
                            />
                            <div className="py-4"></div>

                            <Button backgroundColor="black" color="white" onClickHandler={signJSON}>
                                Sign JSON
                            </Button>
                        </div>
                    )}

                    {formattedJSON ? (
                        <>
                            <div className="py-2"></div>
                            <JsonViewer value={formattedJSON} />
                        </>
                    ) : null}
                    <br />

                    <div className="py-2"></div>
                    <Card dataStore={JsonDataStore} setKeyInDataStore={setRecursiveKeyInDataStore} keys={[]}></Card>
                    <br />

                    {jsonText && signature && (
                        <Button backgroundColor="black" color="white" onClickHandler={generateProof}>
                            {isLoading ? "loading..." : "Generate Proof"}
                        </Button>
                    )}
                    {proofArtifacts && Object.keys(proofArtifacts).length !== 0 ? (
                        <div>
                            <div className="py-2"></div>
                            <div className="flex underlineContainer justify-center items-center text-center">
                                <a
                                    className="viewProof text-underline"
                                    target="_blank"
                                    href={"data:text/json;charset=utf-8," + JSON.stringify(proofArtifacts.proof)}
                                    download={"proof.json"}
                                    rel="noreferrer"
                                >
                                    View Proof
                                </a>
                            </div>
                            <div className="py-2"></div>
                            <Button backgroundColor="black" color="white" onClickHandler={verifyProof}>
                                {isLoading ? "loading..." : "Verify Proof"}
                            </Button>
                        </div>
                    ) : null}
                </div>
                <Toaster />
            </Container>
        </>
    );
}
