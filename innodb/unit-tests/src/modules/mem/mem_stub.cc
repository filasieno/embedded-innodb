
#include <gtest/gtest.h>

class MemTest : public ::testing::Test {
    void SetUp() override {}
};

TEST_F(MemTest, ExampleTest) {
    EXPECT_TRUE(true);
}


