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
    getRecursiveKeyInDataStore,
    checkJsonSchema,
    REQUIRED_FIELDS,
} from "../utilities/json";
import styled from "styled-components";
import axios from "axios";
import { EddsaSignature, VerifyPayload } from "../utilities/types";
import { calculatePoseidon, generateEddsaSignature, hardCodedInput, strHashToBuffer } from "../utilities/crypto";
import { Card } from "../components/card";
import Link from "next/link";
import ReactLoading from "react-loading";
import { producePP } from "../utilities/producePP";

const Container = styled.main`
    .viewProof {
        text-decoration: underline !important;
    }

    .underlineContainer {
        text-decoration: underline !important;
    }
`;

interface Signature {
    R8: string[];
    S: string[];
    pubKey: string[];
}

export default function Home() {
    const [jsonText, setJsonText] = useState<string>("");
    const [isLoading, setIsLoading] = useState<number | undefined>(undefined);
    const [hasKeypair, setHasKeypair] = useState<boolean>(false);
    const [signature, setSignature] = useState<Signature | undefined>(undefined);
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
            ptr["ticked"] = !ptr["ticked"];
        }
        setJsonDataStore(newJson);
    };

    type FullJsonCircuitInput = {
        jsonProgram: Ascii[];
        keys: Ascii[][][];
        values: Ascii[][];
        keysOffset: number[][][];
        valuesOffset: number[][];
        inputReveal: number[];
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
            setIsLoading(1);

            checkJsonSchema(JsonDataStore);
            if (jsonText) {
                // BUILD the revealedFields array;
                var revealedFields: number[] = [];
                for (var key of REQUIRED_FIELDS) {
                    var node = getRecursiveKeyInDataStore(key, JsonDataStore);
                    if (node !== null && !isJSONStore(node)) {
                        revealedFields.push(node["ticked"] ? 1 : 0);
                    }
                }
                const obj = preprocessJson(JSON.parse(jsonText), 150, revealedFields);
                const worker = new Worker("./worker.js");

                if (
                    obj &&
                    typeof hash == "string" &&
                    signature !== undefined
                ) {
                    let objFull: FullJsonCircuitInput = {
                        ...obj,
                        hashJsonProgram: hash,
                        pubKey: signature["pubKey"],
                        R8: signature["R8"],
                        S: signature["S"],
                        inputReveal: revealedFields,
                    };

                    console.log(JSON.stringify(objFull));
                    worker.postMessage([objFull, "./jsonFull_final.zkey"]);
                } else {
                    setIsLoading(undefined);
                    toast.error(
                        "Invalid proving request. Please ensure that your JSON includes the required attributes"
                    );
                    return;
                }

                worker.onmessage = async function (e) {
                    const { proof, publicSignals, error } = e.data;
                    setIsLoading(undefined);
                    if (error) {
                        toast.error("Could not generate proof, invalid signature");
                    } else {
                        setProofArtifacts({ proof, publicSignals });

                        console.log("PROOF SUCCESSFULLY GENERATED: ", proof, publicSignals);
                        toast.success("Generated proof!");
                    }
                };
            }
        } catch (ex) {
            setIsLoading(undefined);
            if (ex instanceof Error && ex.message.startsWith("Unable to generate proof! Missing")) {
                toast.error(ex.message);
                return;
            }
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
                setIsLoading(0);
                const privKey = ed.utils.randomPrivateKey();
                const publicKey = await ed.getPublicKey(privKey);
                await localforage.setItem("zkattestorPrivKey", privKey);
                await localforage.setItem("zkattestorPubKey", publicKey);
                setIsLoading(undefined);
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
        const signature: Signature = await generateEddsaSignature(
            privateKey as Uint8Array,
            // ethers.utils.toUtf8Bytes(newFormattedJSON)
            strHashToBuffer(hash)
        );

        setHash(hash);
        setSignature(signature);
    };

    const verifyProof = async () => {
        try {
            setIsLoading(2);
            const resultVerified = await axios.post<VerifyPayload>("/api/verify", { ...proofArtifacts });
            if (resultVerified.data.isValidProof) {
                toast.success("Successfully verified proof!");
            } else {
                toast.error("Failed to verify proof");
            }
            setIsLoading(undefined);
        } catch (ex) {
            setIsLoading(undefined);
            toast.error("Failed to verify proof");
        }
    };
    const DEFAULT_TEXT = `{\n\t"name":"John Doe",\n\t"age": 42,\n\t"address": "123 Main St"\n}`;

    return (
        <>
            <Head>
                <title>ZK JSON</title>
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
                <div style={{ width: "800px" }} className="font-mono text flex flex-col justify-center items-center">
                    {!hasKeypair ? (
                        "generating your key pair..."
                    ) : (
                        <div className="w-full flex flex-col items-center justify-center">
                            {/* <Editor
                                height="20vh"
                                defaultLanguage="json"
                                defaultValue={DEFAULT_TEXT}
                                options={
                                    {
                                        "minimap":{"enabled": false},
                                        "scrollbar": {"vertical": "hidden"}
                                    }
                                }
                                onMount={() => {
                                    setJsonText(DEFAULT_TEXT);
                                }}
                                onChange={(newVal: string | undefined, _ev: _) => {
                                    if (newVal !== undefined) {
                                        setJsonText(newVal);
                                    }
                                }}
                            /> */}
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

                    {/* {formattedJSON ? (
                        <>
                            <div className="py-2"></div>
                            <JsonViewer value={formattedJSON} />
                        </>
                    ) : null} */}
                    <br />

                    <div className="py-2"></div>
                    {Object.keys(JsonDataStore).length != 0 && (
                        <div className="font-mono">
                            {"{"}
                            <Card
                                dataStore={JsonDataStore}
                                setKeyInDataStore={setRecursiveKeyInDataStore}
                                keys={[]}
                            ></Card>
                            {"}"}
                        </div>
                    )}
                    <br />

                    {jsonText && signature && (
                        <Button backgroundColor="black" color="white" onClickHandler={generateProof}>
                            {isLoading === 1 ? (
                                <ReactLoading type={"spin"} color={"white"} height={20} width={20} />
                            ) : (
                                "Generate Proof"
                            )}
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
                            <div className="flex underlineContainer justify-center items-center text-center">
                                <a
                                    className="viewProof text-underline"
                                    target="_blank"
                                    href={"data:text/json;charset=utf-8," + JSON.stringify(producePP(proofArtifacts.publicSignals))}
                                    download={"proof.json"}
                                    rel="noreferrer"
                                >
                                    View Public Info
                                </a>
                            </div>
                            <div className="py-2"></div>
                            <Button backgroundColor="black" color="white" onClickHandler={verifyProof}>
                                {isLoading === 2 ? "loading..." : "Verify Proof"}
                            </Button>
                        </div>
                    ) : null}
                </div>
                <Toaster />
            </Container>
        </>
    );
}
