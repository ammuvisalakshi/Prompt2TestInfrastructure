from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import CloudFront, APIGateway
from diagrams.aws.storage import S3
from diagrams.aws.security import Cognito, SecretsManager
from diagrams.aws.compute import Lambda, ECS, Fargate
from diagrams.aws.database import Aurora, Dynamodb
from diagrams.aws.ml import Bedrock
from diagrams.aws.management import SystemsManager, Cloudwatch
from diagrams.aws.devtools import Codepipeline
from diagrams.aws.general import Users
from diagrams.aws.containers import ECR

with Diagram(
    "",
    show=False,
    filename="C:/MyProjects/AWS/Prompt2TestInfrastructure/diagrams/prompt2test-architecture",
    direction="TB",
    outformat="png",
    graph_attr={
        "fontsize": "20",
        "bgcolor": "white",
        "fontcolor": "#232f3e",
        "pad": "0.8",
        "splines": "polyline",
        "nodesep": "1.2",
        "ranksep": "1.5",
        "fontname": "Arial",
        "dpi": "150",
        "labelloc": "b",
        "label": "Prompt2Test - AWS Architecture",
    },
    node_attr={
        "fontsize": "11",
        "fontcolor": "#232f3e",
        "fontname": "Arial",
        "width": "1.3",
        "height": "1.3",
    },
    edge_attr={
        "penwidth": "1.5",
        "color": "#545b64",
        "style": "dashed",
        "arrowsize": "0.8",
    },
):
    users = Users("Users")
    s3 = S3("Static Content")
    cf = CloudFront("CloudFront\nDistribution")

    with Cluster("AWS Cloud  (us-east-1)", graph_attr={"bgcolor": "#e6eef8", "pencolor": "#bdd0ea", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e", "margin": "20"}):

        cognito = Cognito("Cognito\nUser Pool")

        with Cluster("API Layer", graph_attr={"bgcolor": "white", "pencolor": "#bdd0ea", "style": "rounded", "penwidth": "1", "fontsize": "12", "fontname": "Arial", "fontcolor": "#545b64"}):
            apigw_rest = APIGateway("REST API")
            apigw_ws = APIGateway("WebSocket API")

        with Cluster("Compute - Application Tier", graph_attr={"bgcolor": "#fdf6e3", "pencolor": "#d4b96a", "style": "rounded", "penwidth": "1.5", "fontsize": "12", "fontname": "Arial", "fontcolor": "#545b64"}):
            bedrock = Bedrock("Bedrock AgentCore\nClaude Sonnet 4.5")
            lambda_fn = Lambda("Test Case\nLambda")

            with Cluster("ECS Cluster", graph_attr={"bgcolor": "white", "pencolor": "#d4b96a", "style": "rounded", "penwidth": "1", "fontsize": "11", "fontname": "Arial", "fontcolor": "#545b64"}):
                ecs = ECS("Playwright MCP")
                fargate = Fargate("Fargate")

        with Cluster("Data Tier", graph_attr={"bgcolor": "#eaf5ea", "pencolor": "#82b882", "style": "rounded", "penwidth": "1.5", "fontsize": "12", "fontname": "Arial", "fontcolor": "#545b64"}):
            aurora = Aurora("Aurora Serverless v2\nPostgreSQL + pgvector")
            dynamo = Dynamodb("DynamoDB\nConfig")

        ssm = SystemsManager("SSM")
        secrets = SecretsManager("Secrets\nManager")
        cw = Cloudwatch("CloudWatch")
        ecr = ECR("ECR")
        pipeline = Codepipeline("CodePipeline")

    # Row 1: Users -> CloudFront -> S3
    users >> Edge(style="solid", color="#232f3e", penwidth="2") >> cf
    cf >> Edge(style="solid", color="#232f3e") >> s3

    # Row 2: CloudFront -> Auth + APIs
    cf >> Edge(label="auth", fontsize="9", fontcolor="#545b64") >> cognito
    cognito >> Edge(label="JWT", fontsize="9", fontcolor="#545b64") >> apigw_rest
    cf >> Edge(style="solid", color="#232f3e") >> apigw_rest
    cf >> Edge(style="solid", color="#7048e8") >> apigw_ws

    # Row 3: APIs -> Compute
    apigw_rest >> Edge(style="solid", color="#232f3e") >> lambda_fn
    apigw_ws >> Edge(style="solid", color="#7048e8", label="stream", fontsize="9", fontcolor="#7048e8") >> bedrock
    bedrock >> Edge(label="uses", fontsize="9", fontcolor="#545b64") >> ecs

    # Row 4: Compute -> Data
    lambda_fn >> Edge(label="reads/writes", fontsize="9", fontcolor="#545b64") >> aurora
    lambda_fn >> Edge(label="config", fontsize="9", fontcolor="#545b64") >> dynamo
    bedrock >> Edge(label="stores", fontsize="9", fontcolor="#545b64") >> aurora

    # Supporting (fewer lines)
    lambda_fn >> ssm
    lambda_fn >> secrets
    ecr >> Edge(label="image", fontsize="9", fontcolor="#545b64") >> ecs
    pipeline >> Edge(label="deploys", fontsize="9", fontcolor="#545b64") >> lambda_fn
