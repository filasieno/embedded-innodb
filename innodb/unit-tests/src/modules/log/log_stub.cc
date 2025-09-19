
#include <gtest/gtest.h>

class LogTest : public ::testing::Test {
    void SetUp() override {}
};

TEST_F(LogTest, ExampleTest) {
    EXPECT_TRUE(true);
}


