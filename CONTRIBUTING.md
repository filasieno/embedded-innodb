# Contribution Guidelines

## C++ Code Style

1. All iterators should be named, `it`. Example:

    ```c++
    for(auto it : map.find(key); it != map.end()){
        // ...
    }
    ```

   If there is a possibility for name collision, bound the scope. Example:

    ```c++
    {
        auto it = name_lookup.find(key);
        // ...
    }
   
   // <awesome code here>
   
   {
      auto it = id_lookup.find(id);
      // ...
   }
   ```

2. Class/Struct names should be upper case first letter, and then snake case. Example:

    ```C++
        struct Table_dict_data;
        struct Buf_pool_manager;
    ```

3. All internal struct members should be prefixed with `m_`; Example:

   ```c++
    struct Table_dict_data{
        std::string m_name; 
        std::uint64_t m_id;
        // ....
    };
    ```

4. Tag the functions appropriately with `const`, `[[nodiscard]]`, and `noexcept` if required. Example:

    ```c++
    [[nodiscard]] bool enqueue(T const &data) noexcept;
    ```

5. More coming soon !!
