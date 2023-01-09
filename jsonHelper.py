# Given a string, convert it to an array of unicode characters
def string_to_array(json):
    return [ord(x) for x in json]

def dict_to_string(dictionary):
    # remove spaces and replace single quotes with double quotes
    string = str(dictionary)
    string = string.replace("'", '"')
    string = string.replace(" ", "")
    return string

print(string_to_array(dict_to_string({"name": "foobar", "value": "123"})))