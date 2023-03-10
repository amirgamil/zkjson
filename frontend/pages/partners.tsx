import Head from "next/head";
import styles from "../styles/Home.module.css";
import { Textarea } from "../components/textarea";
import React, { useEffect, useRef, useState } from "react";
import { Button } from "../components/button";
import localforage from "localforage";
import * as ed from "@noble/ed25519";
import { JsonViewer } from "@textea/json-viewer";

import toast, { Toaster } from "react-hot-toast";
import {
    checkJsonSchema,
    createJson,
    getRecursiveKeyInDataStore,
    isJSON,
    isJSONStore,
    JSON_EL,
    JSON_STORE,
    MAX_JSON_LENGTH,
    preprocessJson,
    ProofArtifacts,
    REQUIRED_FIELDS,
    toAscii,
} from "../utilities/json";
import styled from "styled-components";
import axios from "axios";
import { ExtractedJSONSignature, VerifyPayload } from "../utilities/types";
import {
    calculatePoseidon,
    extractPartsFromSignature,
    extractSignatureInputs,
    strHashToBuffer,
} from "../utilities/crypto";
import { Card } from "../components/card";
import Link from "next/link";
import ReactLoading from "react-loading";

import JSConfetti from "js-confetti";
import { producePP } from "../utilities/producePP";

const Container = styled.main`
    .viewProof {
        text-decoration: underline !important;
    }

    .underlineContainer {
        text-decoration: underline !important;
    }
`;

export default function Partners() {
    const [jsonText, setJsonText] = useState<string>("");
    const [isLoading, setIsLoading] = useState<number | undefined>(2);
    const [hasKeypair, setHasKeypair] = useState<boolean>(false);
    const [proofArtifacts, setProofArtifacts] = useState<ProofArtifacts | undefined>(undefined);
    const [formattedJSON, setFormattedJSON] = useState<string | undefined>(undefined);
    const [JsonDataStore, setJsonDataStore] = useState<JSON_STORE>({});
    const [confetti, setConfetti] = useState<any>(undefined);

    const circuitInputs = useRef<ExtractedJSONSignature & { hash: string }>();

    const setRecursiveKeyInDataStore = (keys: string[]) => {
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

    const generateProof = async () => {
        try {
            if (!isJSON(jsonText) || !circuitInputs.current) {
                toast.error("Invalid JSON");
                return;
            }
            setIsLoading(1);
            checkJsonSchema(JsonDataStore);
            // hardCoded.jsonProgram.map(BigInt);
            const sigParts = extractPartsFromSignature(
                circuitInputs.current.packedSignature,
                strHashToBuffer(circuitInputs.current.hash),
                circuitInputs.current.servicePubkey
            );

            var revealedFields: number[] = [];
            for (var key of REQUIRED_FIELDS) {
                var node = getRecursiveKeyInDataStore(key, JsonDataStore);
                if (node !== null && !isJSONStore(node)) {
                    revealedFields.push(node["ticked"] ? 1 : 0);
                }
            }
            const hash = circuitInputs.current.hash;
            const formattedJSON = circuitInputs.current.formattedJSON;
            const obj = preprocessJson(circuitInputs.current.jsonText, MAX_JSON_LENGTH, revealedFields);

            const finalInput = {
                ...sigParts,
                hashJsonProgram: hash,
                jsonProgram: formattedJSON,
                ...obj,
                inputReveal: revealedFields,
            };

            console.log("HELLLL", finalInput);

            const worker = new Worker("./worker.js");
            worker.postMessage([finalInput, "./jsonFull_final.zkey"]);

            worker.onmessage = async function (e) {
                const { proof, publicSignals, error } = e.data;
                if (error) {
                    toast.error("Could not generate proof, invalid signature");
                } else {
                    setProofArtifacts({ proof, publicSignals });
                    console.log("PROOF SUCCESSFULLY GENERATED: ", proof, publicSignals);
                    toast.success("Generated proof!");
                }
                setIsLoading(undefined);
            };
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

    const generateJSON = async () => {
        const extracted = extractSignatureInputs(jsonText);
        let newJsonDataStore: JSON_STORE = {};
        let parsedJson = extracted.jsonText;

        createJson(parsedJson, newJsonDataStore);
        setJsonDataStore(newJsonDataStore);

        let hash = await calculatePoseidon(toAscii(extracted.formattedJSON));

        circuitInputs.current = { ...extracted, hash };
    };

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

    useEffect(() => {
        setConfetti(new JSConfetti());
    }, []);

    const verifyProof = async () => {
        try {
            setIsLoading(2);
            const resultVerified = await axios.post<VerifyPayload>("/api/verify", { ...proofArtifacts });
            if (resultVerified.data.isValidProof) {
                toast.success("Successfully verified proof!");
                confetti
                    .addConfetti({
                        confettiRadius: 50,
                        emojis: ["????"],
                    })
                    .then((_: any) => confetti.clearCanvas());
            } else {
                toast.error("Failed to verify proof");
            }
            setIsLoading(undefined);
        } catch (ex) {
            setIsLoading(undefined);
            toast.error("Failed to verify proof");
        }
    };

    console.log("loading: ", isLoading);
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
                        <div style={{ flex: "0.5" }}></div>
                        <h1 style={{ flex: "0.55" }} className="text-xl">
                            zkJSON
                        </h1>
                        <Link href="/">Home</Link>
                    </div>
                </div>

                <p className="mb-2">Paste your JSON then select JSON elements to reveal in ZK-proof</p>
                <div className="py-2"></div>
                <div style={{ width: "800px" }} className="flex flex-col justify-center items-center">
                    <Textarea
                        placeholder={"Paste the output of any one of our trusted APIs here (which signs the JSON)"}
                        value={jsonText}
                        onChangeHandler={(newVal: string) => {
                            setJsonText(newVal);
                        }}
                    />
                    <div className="py-4"></div>
                    {formattedJSON ? (
                        <>
                            <div className="py-2"></div>
                            <JsonViewer value={formattedJSON} />
                        </>
                    ) : null}

                    <Button backgroundColor="black" color="white" onClickHandler={generateJSON}>
                        Parse JSON
                    </Button>
                    <div className="py-4"></div>

                    <div className="py-2"></div>
                    <Card dataStore={JsonDataStore} setKeyInDataStore={setRecursiveKeyInDataStore} keys={[]}></Card>
                    <br />

                    {Object.keys(JsonDataStore).length > 0 ? (
                        <Button backgroundColor="black" color="white" onClickHandler={generateProof}>
                            {isLoading === 1 ? (
                                <ReactLoading type={"spin"} color={"white"} height={20} width={20} />
                            ) : (
                                "Generate Proof"
                            )}
                        </Button>
                    ) : null}

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
                                    download={"publicParams.json"}
                                    rel="noreferrer"
                                >
                                    View Public Info
                                </a>
                            </div>
                            <div className="py-2"></div>
                            <div className="w-full flex justify-center items-center">
                                <Button backgroundColor="black" color="white" onClickHandler={verifyProof}>
                                    {isLoading === 2 ? (
                                        <ReactLoading type={"spin"} color={"white"} height={20} width={20} />
                                    ) : (
                                        "Verify Proof"
                                    )}
                                </Button>
                            </div>
                        </div>
                    ) : null}
                </div>
                <Toaster />
            </Container>
        </>
    );
}
