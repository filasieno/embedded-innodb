
#include <gtest/gtest.h>

class OsTest : public ::testing::Test {
    void SetUp() override {}
};

TEST_F(OsTest, ExampleTest) {
    EXPECT_TRUE(true);
}


