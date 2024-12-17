exports.handler = async (event) => {
    console.log("Event received:", JSON.stringify(event, null, 2));
    // Add logic to handle alerts and notifications
    return {
        statusCode: 200,
        body: "Alert handled successfully!",
    };
};

