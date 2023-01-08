# Given a string, convert it to an array of unicode characters
def string_to_array(json):
    return [ord(x) for x in json]

print(string_to_array("{\"name\":\"foobar\"}"))
print(len("{\"name\":\"foobar\"}"))