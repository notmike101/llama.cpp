```cpp
#include <string_view>
#include <vector>
#include <cassert>
#include <iostream>

bool valid_brackets(std::string_view s) {
    std::vector<char> stack;
    const char* openers = "([{ ";
    const char* closing = ")]} ";
    
    for (char c : s) {
        bool is_opens = false;
        bool is_closer = false;
        char current = c;
        
        for (int i = 0; i < 3; ++i) {
            if (current == openers[i]) {
                is_opens = true;
                break;
            }
            if (current == closing[i]) {
                is_closer = true;
                break;
            }
        }
        
        if (is_opens) {
            stack.push_back(c);
        } else if (is_closer) {
            if (stack.empty()) {
                return false;
            }
            char expected = stack.back();
            stack.pop_back();
            if (expected != openers[0] || c != closing[0]) {
                if (expected == '(' && c != ')') return false;
                if (expected == '[' && c != ']') return false;
                if (expected == '{' && c != '}') return false;
            }
        }
    }
    
    return stack.empty();
}

int main() {
    assert(valid_brackets("") == true);
    assert(valid_brackets("()") == true);
    assert(valid_brackets("[]") == true);
    assert(valid_brackets("{}") == true);
    assert(valid_brackets("()[]{}") == true);
    assert(valid_brackets("({[]})") == true);
    assert(valid_brackets("({[]})") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("{") == false);
    assert(valid_brackets("}") == false);
    assert(valid_brackets("a(b)c") == true);
    std::cout << "All tests passed." << std::endl;
    return 0;
}
```