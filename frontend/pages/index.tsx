import Head from "next/head";
import styles from "../styles/Home.module.css";
import { Textarea } from "../components/textarea";
import React, { useEffect, useMemo, useRef, useState } from "react";
import { Button } from "../components/button";
import localforage from "localforage";
import * as ed from "@noble/ed25519";
import * as ethers from "ethers";
import { JsonViewer } from "@textea/json-viewer";

import toast, { Toaster } from "react-hot-toast";
import { isJSON, JSONStringifyCustom, padJSONString, toAscii } from "../utilities/json";
import styled from "styled-components";
import axios from "axios";
import { VerifyPayload } from "../utilities/types";
import { generateEddsaSignature, hardCodedInput } from "../utilities/crypto";

import { buildPoseidon } from "circomlibjs";


type Ascii = number;

async function calculatePoseidon(json: Ascii[]): Promise<string> {
	const poseidon = await buildPoseidon();

	let poseidonRes = poseidon(json.slice(0, 16));
	let i = 16;
	while (i < json.length) {
		poseidonRes = poseidon([poseidonRes].concat(json.slice(i, i+15)));
		i += 15;
	}
	return poseidon.F.toObject(poseidonRes).toString();
}

interface JSON_EL {
    value: string;
    ticked: boolean;
}

interface JSON_STORE {
    [key: string]: JSON_EL | JSON_STORE;
}

function isJSONStore(store: JSON_STORE | JSON_EL): store is JSON_STORE { 
    return store && !("value" in store);
}  

interface ProofArtifacts {
    publicSignals: string[];
    proof: Object;
}

const Container = styled.main`
    .viewProof {
        text-decoration: underline !important;
    }
`;

const getRecursiveKeyInDataStore = (keys: string[], json: JSON_STORE) => {
    let ptr: JSON_EL | JSON_STORE = json;
    //TODO: handle nesting
    for (var key of keys) {
        if (isJSONStore(ptr) && typeof key === "string" && ptr[key] && ptr[key]) {
            ptr = ptr[key];
        } else {
            // ERROR
        }
    }
    return ptr;
};


function Card(props: { dataStore: JSON_STORE, setKeyInDataStore: any, keys: string[]}) {
    // jsonText

    const handleCheckmarkCheck = (event, keys: string[]) => {
        props.setKeyInDataStore(keys, event.target.checked);
    };
    const [fetchJson, setFetchedJson] = useState<null | JSON_STORE | JSON_EL>(null);
    const [numKeys, setNumKeys] = useState<number>(0);

    useEffect(() => {
        setFetchedJson(
            getRecursiveKeyInDataStore(props.keys, props.dataStore)
        );
        setNumKeys(Object.keys(
            getRecursiveKeyInDataStore(props.keys, props.dataStore)
        ).length);
    });

    return <>
        <ul className="ml-4">
            <>
                {
                    (fetchJson && isJSONStore(fetchJson)) && <>
                        {Object.keys(
                            getRecursiveKeyInDataStore(props.keys, props.dataStore)
                        ).map((key: string, index: any) => {
                            return (
                                <>
                                    {
                                        isJSONStore(fetchJson[key]) ? 
                                        <>
                                            <strong className="mb-4">{key}: &#123;</strong>
                                            <Card dataStore={props.dataStore} setKeyInDataStore={props.setKeyInDataStore} keys={props.keys.concat([key])}></Card>
                                            <strong className="mb-4">&#125;
                                                {
                                                    index != numKeys - 1 && <>
                                                        ,
                                                    </>
                                                }
                                            </strong>
                                        </> : <>
                                            <div key={index}>
                                                <strong className="mb-4 mr-4">{key}: </strong>
                                                <label className="inline-flex items-center">
                                                    <input
                                                        type="checkbox"
                                                        className="mr-4 pt-2 form-checkbox h-4 w-4 text-indigo-600 transition duration-150 ease-in-out"
                                                        onChange={(e) => handleCheckmarkCheck(e, props.keys.concat([key]))}
                                                        checked={fetchJson[key] && fetchJson[key].ticked ? true : false}
                                                    />
                                                </label>
                                                <strong className="mb-4 mr-4">
                                                    {
                                                        index != numKeys - 1 && <>
                                                            ,
                                                        </>
                                                    }
                                                </strong>
                                            </div>
                                        </>
                                    }
                                </>
                            )
                        })}
                    </>
                }
            </>
        </ul>
    </>;
}

export default function Home() {
    const [jsonText, setJsonText] = useState<string>("");
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [hasKeypair, setHasKeypair] = useState<boolean>(false);
    const [signature, setSignature] = useState<Object | undefined>(undefined);
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

    const generateProof = async () => {
        try {
            if (!isJSON(jsonText)) {
                toast.error("Invalid JSON");
                return;
            }
            setIsLoading(true);
            // hardCoded.jsonProgram.map(BigInt);

            const worker = new Worker("./worker.js");
            worker.postMessage([hardCodedInput, "./jsonFull_final.zkey"]);
            worker.onmessage = async function (e) {
                const { proof, publicSignals } = e.data;
                setProofArtifacts({ proof, publicSignals });
                console.log("PROOF SUCCESSFULLY GENERATED: ", proof, publicSignals);
                toast.success("Generated proof!");
                setIsLoading(false);
            };
        } catch (ex) {
            console.error(ex);
            toast.error("Something went wrong :(");
        }
    };

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
        const newFormattedJSON = padJSONString(JSON.stringify(JSON.parse(jsonText)), 50);
        setFormattedJSON(newFormattedJSON);

        // Populate JSON_STORE with data from JSON.parse(jsonText);
        let newJsonDataStore: JSON_STORE = {};
        let parsedJson = JSON.parse(jsonText);

        const createJson = (parsedJsonPtr: any, parsedJsonDataStorePtr: any) => {
            for (var key in parsedJsonPtr) {
                if (typeof parsedJsonPtr[key] === 'string') {
                    let newLeaf: JSON_EL = {
                        value: parsedJsonPtr[key],
                        ticked: false
                    }
                    parsedJsonDataStorePtr[key] = newLeaf;
                } else {
                    let newJsonStore: JSON_STORE = {};
                    parsedJsonDataStorePtr[key] = newJsonStore;
                    createJson(parsedJsonPtr[key], parsedJsonDataStorePtr[key]);
                }
            }
        }
        createJson(parsedJson, newJsonDataStore);
        console.log(newJsonDataStore)
        setJsonDataStore(newJsonDataStore);
        console.log("formatted: ", newFormattedJSON.length, jsonText.length);
        let hash = await calculatePoseidon(toAscii(newFormattedJSON));
        console.log("hash: ", hash)
        let hashValue = BigInt(hash);
        let hashArr = [];
        for (let i = 0; i < 16; i++) {
            hashArr.push(Number(hashValue % BigInt(256)));
            hashValue = hashValue / BigInt(256);
        }
        // const signature = await ed.sign(ethers.utils.toUtf8Bytes(newFormattedJSON), privateKey as string);
        const signature = await generateEddsaSignature(
            privateKey as Uint8Array,
            // ethers.utils.toUtf8Bytes(newFormattedJSON)
            Uint8Array.from(hashArr)
        );
        // console.log(JSONStringifyCustom(signature));
        setSignature(signature);
    };

    const recursivelyResolveObject = (obj: Record<string, any>) => {
        if (typeof obj !== "object") {
            return obj;
        }
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
                <div className={`${styles.coolBackground} flex justify-center items-center py-2 strong`}>
                    <h1 className="text-xl">zkJSON</h1>
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
                            <div className="flex justify-center items-center text-center">
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
