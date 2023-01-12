export function isJSON(jsonText: any) {
    try {
        JSON.parse(jsonText);
        return true;
    } catch (ex) {
        return false;
    }
}
