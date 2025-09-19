
#include <gtest/gtest.h>

class ApiTest : public ::testing::Test {
    void SetUp() override {}
};

TEST_F(ApiTest, ExampleTest) {
    EXPECT_TRUE(1 + 1 == 2);
}


