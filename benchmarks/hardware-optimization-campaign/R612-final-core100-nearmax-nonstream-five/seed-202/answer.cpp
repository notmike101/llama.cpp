#include <string_view>
#include <vector>
#include <cassert>
#include <iostream>

bool valid_brackets(std::string_view s) {
    std::vector<char> stack;
    stack.reserve(s.size());
    for (char c : s) {
        if (c == '(') {
            stack.push_back(')');
        } else if (c == '[') {
            stack.push_back(']');
        } else if (c == '{') {
            stack.push_back('}');
        } else if (c == ')' || c == ']' || c == '}') {
            if (stack.empty() || stack.back() != c) {
                return false;
            }
            stack.pop_back();
        }
    }
    return stack.empty();
}

int main() {
    // Valid simple brackets
    assert(valid_brackets("()"));
    assert(valid_brackets("[]"));
    assert(valid_brackets("{}"));
    
    // Valid nested brackets
    assert(valid_brackets("([{}])"));
    assert(valid_brackets("(([]))"));
    
    // Invalid crossing brackets
    assert(!valid_brackets("([)]"));
    assert(!valid_brackets("((]"));
    
    // Unmated closing brackets
    assert(!valid_brackets("(()"));
    assert(!valid_brackets(")))"));
    
    // Empty string
    assert(valid_brackets(""));
    
    // Only non-bracket text
    assert(valid_brackets("hello"));
    assert(valid_brackets("12345"));
    assert(valid_brackets("!@#"));
    
    // Mixed text and brackets
    assert(valid_brackets("a(b)c[d]e{f}g"));
    assert(!valid_brackets("a(b)c[d]e{f}g]"));
    
    std::cout << "All tests passed." << std::endl;
    return 0;
}